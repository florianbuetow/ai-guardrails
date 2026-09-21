#include <ctype.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define LINE_CAPACITY 4096U
#define TOKEN_CAPACITY 128U

typedef struct {
    const char *path;
    unsigned long line;
    unsigned int errors;
    unsigned int main_count;
    unsigned int data_origin_count;
    unsigned int code_origin_count;
    unsigned int greg_count;
    unsigned int segment;
    unsigned long pending_exit_line;
    int quiet;
} FileState;

static const char *const instructions[] = {
    "ADD",  "ADDU", "AND",  "BDIF", "BN",   "BNN",  "BNP",  "BNZ",
    "BP",   "BZ",   "CMP",  "CMPU", "CSN",  "CSNN", "CSNP", "CSNZ",
    "CSP",  "CSZ",  "DIV",  "DIVU", "GO",   "JMP",  "LDA",  "LDB",  "LDBU",
    "LDO",  "LDOU", "LDT",  "LDTU", "LDW",  "LDWU", "MUL",  "MULU",
    "MUX",  "NAND", "NEG",  "NEGU", "NOR",  "NXOR", "ODIF", "OR",
    "ORH",  "ORL",  "ORMH", "ORML", "PBN",  "PBNN", "PBNP", "PBNZ",
    "PBP",  "PBZ",  "POP",  "PUSHJ","SET",  "SETH", "SETL", "SETMH",
    "SETML","SL",   "SLU",  "SR",   "SRU",  "STB",  "STBU", "STCO",
    "STO",  "STOU", "STT",  "STTU", "STW",  "STWU", "SUB",  "SUBU",
    "TDIF", "TRAP", "WDIF", "XOR",  "ZSN",  "ZSNN", "ZSNP", "ZSNZ",
    "ZSP",  "ZSZ"
};

static const char *const directives[] = {
    "BYTE", "GREG", "IS", "LOC", "OCTA", "TETRA", "WYDE"
};

static int in_list(const char *value, const char *const *list, size_t count) {
    size_t index;
    for (index = 0U; index < count; ++index) {
        if (strcmp(value, list[index]) == 0) {
            return 1;
        }
    }
    return 0;
}

static void diagnose(FileState *state, size_t column, const char *message) {
    if (!state->quiet) {
        (void)fprintf(stderr, "%s:%lu:%lu: error: %s\n", state->path, state->line,
                      (unsigned long)column, message);
    }
    ++state->errors;
}

static int is_pascal_symbol(const char *text) {
    size_t index;
    if (!isupper((unsigned char)text[0])) {
        return 0;
    }
    for (index = 1U; text[index] != '\0'; ++index) {
        if (!isalnum((unsigned char)text[index])) {
            return 0;
        }
    }
    return 1;
}

static int has_suffix(const char *text, const char *suffix) {
    size_t text_length = strlen(text);
    size_t suffix_length = strlen(suffix);
    return text_length >= suffix_length &&
           strcmp(text + text_length - suffix_length, suffix) == 0;
}

static void trim_right(char *text) {
    size_t length = strlen(text);
    while (length > 0U && isspace((unsigned char)text[length - 1U])) {
        text[--length] = '\0';
    }
}

static char *trim_left(char *text) {
    while (isspace((unsigned char)*text)) {
        ++text;
    }
    return text;
}

static void remove_comment(FileState *state, char *line) {
    size_t index;
    int quoted = 0;
    for (index = 0U; line[index] != '\0'; ++index) {
        if (line[index] == '"') {
            quoted = !quoted;
        } else if (line[index] == '%' && !quoted) {
            if (index > 0U && line[index - 1U] != ' ') {
                diagnose(state, index + 1U, "comments must be preceded by a space");
            }
            line[index] = '\0';
            trim_right(line);
            return;
        }
    }
    if (quoted) {
        diagnose(state, index + 1U, "unterminated string literal");
    }
}

static int copy_token(FileState *state, char *destination, size_t capacity,
                      const char *start, size_t length, size_t column) {
    if (length == 0U || length >= capacity) {
        diagnose(state, column, "token is empty or too long");
        destination[0] = '\0';
        return 0;
    }
    (void)memcpy(destination, start, length);
    destination[length] = '\0';
    return 1;
}

static void check_operand_spacing(FileState *state, const char *operands, size_t column) {
    size_t index;
    int quoted = 0;
    for (index = 0U; operands[index] != '\0'; ++index) {
        if (operands[index] == '"') {
            quoted = !quoted;
        } else if (!quoted && operands[index] == ',') {
            if (index > 0U && isspace((unsigned char)operands[index - 1U])) {
                diagnose(state, column + index, "no space is allowed before a comma");
            }
            if (isspace((unsigned char)operands[index + 1U])) {
                diagnose(state, column + index + 2U, "no space is allowed after a comma");
            }
        }
    }
}

static int parse_register(const char *text, size_t *consumed, unsigned long *number) {
    char *end;
    if (text[0] != '$' || !isdigit((unsigned char)text[1])) {
        return 0;
    }
    errno = 0;
    *number = strtoul(text + 1, &end, 10);
    if (errno != 0 || end == text + 1) {
        return 0;
    }
    *consumed = (size_t)(end - text);
    return 1;
}

static void check_registers(FileState *state, const char *operation,
                            const char *operands, size_t column) {
    size_t index = 0U;
    int quoted = 0;
    while (operands[index] != '\0') {
        size_t consumed;
        unsigned long number;
        if (operands[index] == '"') {
            quoted = !quoted;
            ++index;
            continue;
        }
        if (!quoted && parse_register(operands + index, &consumed, &number)) {
            if (number > 255UL) {
                diagnose(state, column + index, "register number must be in $0..$255");
            } else if (strcmp(operation, "IS") == 0) {
                if (number == 255UL) {
                    diagnose(state, column + index, "$255 cannot have a register alias");
                }
            } else if (number != 255UL) {
                diagnose(state, column + index,
                         "use a PascalCase name ending in Reg instead of a raw local register");
            }
            index += consumed;
            continue;
        }
        ++index;
    }
}

static int valid_symbol_operand(const char *text) {
    size_t index;
    if (!is_pascal_symbol(text)) {
        return 0;
    }
    for (index = 0U; text[index] != '\0'; ++index) {
        if (!isalnum((unsigned char)text[index])) {
            return 0;
        }
    }
    return 1;
}

static void check_register_255(FileState *state, const char *operation,
                               const char *operands, size_t column) {
    const char *occurrence = strstr(operands, "$255");
    int allowed = 0;
    if (occurrence == NULL) {
        return;
    }
    if (strcmp(operation, "SETL") == 0 && strcmp(operands, "$255,0") == 0) {
        allowed = 1;
    } else if (strcmp(operation, "LDA") == 0 && strncmp(operands, "$255,", 5U) == 0 &&
               valid_symbol_operand(operands + 5U)) {
        allowed = 1;
    }
    if (!allowed || strstr(occurrence + 4, "$255") != NULL) {
        diagnose(state, column + (size_t)(occurrence - operands),
                 "$255 is reserved for LDA of an I/O buffer and SETL $255,0 before Halt");
    }
}

static void check_magic_numbers(FileState *state, const char *operation,
                                const char *operands, size_t column) {
    size_t index;
    int quoted = 0;
    if (strcmp(operation, "LOC") == 0 || strcmp(operation, "BYTE") == 0 ||
        strcmp(operation, "WYDE") == 0 || strcmp(operation, "TETRA") == 0 ||
        strcmp(operation, "OCTA") == 0) {
        return;
    }
    for (index = 0U; operands[index] != '\0'; ++index) {
        if (operands[index] == '"') {
            quoted = !quoted;
        } else if (!quoted && operands[index] == '#') {
            diagnose(state, column + index,
                     "hexadecimal magic values are forbidden in instruction operands");
        }
    }
}

static void check_first_operand(FileState *state, const char *operation,
                                const char *operands, size_t column,
                                int is_instruction) {
    char first[TOKEN_CAPACITY];
    size_t length = 0U;
    if (!is_instruction || strcmp(operation, "TRAP") == 0 ||
        strcmp(operation, "JMP") == 0 || strcmp(operation, "POP") == 0 ||
        strcmp(operation, "PUSHJ") == 0) {
        return;
    }
    while (operands[length] != '\0' && operands[length] != ',') {
        ++length;
    }
    if (!copy_token(state, first, sizeof(first), operands, length, column)) {
        return;
    }
    if (strcmp(first, "$255") != 0 &&
        (!is_pascal_symbol(first) || !has_suffix(first, "Reg"))) {
        diagnose(state, column,
                 "the first register operand must be a named *Reg alias or explicit $255");
    }
}

static void check_operation_policy(FileState *state, const char *label,
                                   const char *operation, const char *operands,
                                   size_t operand_column, int is_instruction) {
    if (strcmp(operation, "LOC") == 0) {
        if (label[0] != '\0') {
            diagnose(state, 1U, "LOC must not have a label");
        }
        if (strcmp(operands, "#100") == 0) {
            ++state->code_origin_count;
            if (state->segment != 1U) {
                diagnose(state, operand_column,
                         "LOC #100 must follow the single data segment");
            }
            state->segment = 2U;
        } else if (strcmp(operands, "Data_Segment") != 0) {
            diagnose(state, operand_column, "LOC is restricted to #100 or Data_Segment");
        } else {
            ++state->data_origin_count;
            if (state->segment != 0U) {
                diagnose(state, operand_column, "LOC Data_Segment must occur exactly once and first");
            }
            state->segment = 1U;
        }
    } else if (strcmp(operation, "IS") == 0) {
        size_t consumed = 0U;
        unsigned long number = 0UL;
        if (label[0] == '\0' || !has_suffix(label, "Reg")) {
            diagnose(state, 1U, "register aliases must be PascalCase names ending in Reg");
        }
        if (!parse_register(operands, &consumed, &number) || operands[consumed] != '\0' ||
            number > 254UL) {
            diagnose(state, operand_column, "IS may only define one local register in $0..$254");
        }
    } else if (strcmp(operation, "TRAP") == 0) {
        if (strcmp(operands, "0,Fputs,StdOut") != 0 &&
            strcmp(operands, "0,Halt,0") != 0) {
            diagnose(state, operand_column,
                     "TRAP must be exactly 0,Fputs,StdOut or 0,Halt,0");
        }
    }
    if ((strcmp(operation, "BYTE") == 0 || strcmp(operation, "WYDE") == 0 ||
         strcmp(operation, "TETRA") == 0 || strcmp(operation, "OCTA") == 0) &&
        state->segment != 1U) {
        diagnose(state, 9U, "data directives are only allowed in the data segment");
    }
    if (is_instruction && state->segment != 2U) {
        diagnose(state, 9U, "instructions are only allowed after LOC #100");
    }
    if (strcmp(operation, "IS") == 0 && state->segment == 0U) {
        diagnose(state, 9U, "register aliases must follow LOC Data_Segment");
    }
    if (strcmp(operation, "GREG") == 0 &&
        (label[0] != '\0' || strcmp(operands, "@") != 0)) {
        diagnose(state, 9U, "GREG is restricted to the unlabeled MMIXAL setup form GREG @");
    }
    if (strcmp(operation, "GREG") == 0) {
        ++state->greg_count;
        if (state->segment != 1U) {
            diagnose(state, 9U, "GREG @ must occur in the data segment before LOC #100");
        }
    }
    if (strcmp(label, "Main") == 0) {
        if (is_instruction) {
            ++state->main_count;
        } else {
            diagnose(state, 1U, "Main must label an instruction, not a directive");
        }
    }
}

static void check_exit_sequence(FileState *state, const char *operation,
                                const char *operands) {
    int is_halt = strcmp(operation, "TRAP") == 0 &&
                  strcmp(operands, "0,Halt,0") == 0;
    int sets_exit = strcmp(operation, "SETL") == 0 &&
                    strcmp(operands, "$255,0") == 0;
    if (state->pending_exit_line != 0UL && !is_halt) {
        (void)fprintf(stderr,
                      "%s:%lu:9: error: SETL $255,0 must be followed by TRAP 0,Halt,0\n",
                      state->path, state->pending_exit_line);
        ++state->errors;
    }
    if (is_halt && state->pending_exit_line == 0UL) {
        diagnose(state, 9U, "TRAP 0,Halt,0 must immediately follow SETL $255,0");
    }
    state->pending_exit_line = sets_exit ? state->line : 0UL;
}

static void validate_source_line(FileState *state, char *line) {
    char label[TOKEN_CAPACITY];
    char operation[TOKEN_CAPACITY];
    char *cursor;
    char *operand_start;
    size_t length;
    size_t operation_start;
    size_t operation_length;
    int is_instruction;
    int is_directive;

    remove_comment(state, line);
    trim_right(line);
    if (line[0] == '\0') {
        return;
    }
    length = strlen(line);
    label[0] = '\0';
    if (!isspace((unsigned char)line[0])) {
        size_t label_length = 0U;
        while (label_length < length && !isspace((unsigned char)line[label_length])) {
            ++label_length;
        }
        if (!copy_token(state, label, sizeof(label), line, label_length, 1U)) {
            return;
        }
        if (!is_pascal_symbol(label)) {
            diagnose(state, 1U, "labels must be PascalCase ASCII letters and digits");
        }
        if (label_length > 7U) {
            diagnose(state, 1U, "labels must fit before operation column 9");
        }
    }
    if (length < 9U ||
        (!isspace((unsigned char)line[0]) && strlen(label) >= length)) {
        diagnose(state, length + 1U, "operation must begin in column 9");
        return;
    }
    operation_start = 8U;
    if (line[operation_start] == '\0' || isspace((unsigned char)line[operation_start])) {
        diagnose(state, 9U, "operation must begin in column 9");
        return;
    }
    cursor = line + operation_start;
    operation_length = 0U;
    while (cursor[operation_length] != '\0' &&
           !isspace((unsigned char)cursor[operation_length])) {
        ++operation_length;
    }
    if (!copy_token(state, operation, sizeof(operation), cursor, operation_length, 9U)) {
        return;
    }
    is_instruction = in_list(operation, instructions,
                             sizeof(instructions) / sizeof(instructions[0]));
    is_directive = in_list(operation, directives, sizeof(directives) / sizeof(directives[0]));
    if (!is_instruction && !is_directive) {
        diagnose(state, 9U, "operation is not in the project allowlist");
    }
    operand_start = cursor + operation_length;
    if (*operand_start == '\0') {
        diagnose(state, operation_start + operation_length + 1U, "operation requires operands");
        return;
    }
    if (*operand_start != ' ') {
        diagnose(state, operation_start + operation_length + 1U,
                 "separate the operation and operands with spaces");
        return;
    }
    operand_start = trim_left(operand_start);
    if (*operand_start == '\0') {
        diagnose(state, length + 1U, "operation requires operands");
        return;
    }
    check_operand_spacing(state, operand_start, (size_t)(operand_start - line) + 1U);
    check_first_operand(state, operation, operand_start,
                        (size_t)(operand_start - line) + 1U, is_instruction);
    check_registers(state, operation, operand_start, (size_t)(operand_start - line) + 1U);
    check_register_255(state, operation, operand_start, (size_t)(operand_start - line) + 1U);
    check_magic_numbers(state, operation, operand_start, (size_t)(operand_start - line) + 1U);
    check_operation_policy(state, label, operation, operand_start,
                           (size_t)(operand_start - line) + 1U, is_instruction);
    check_exit_sequence(state, operation, operand_start);
}

static int validate_file(const char *path) {
    FILE *input;
    int open_error;
    FileState state;
    char line[LINE_CAPACITY];
    size_t path_length = strlen(path);

    state.path = path;
    state.line = 0UL;
    state.errors = 0U;
    state.main_count = 0U;
    state.data_origin_count = 0U;
    state.code_origin_count = 0U;
    state.greg_count = 0U;
    state.segment = 0U;
    state.pending_exit_line = 0UL;
    state.quiet = 0;
    if (path_length < 4U || strcmp(path + path_length - 4U, ".mms") != 0) {
        (void)fprintf(stderr, "%s: error: source path must end in .mms\n", path);
        return 1;
    }
    input = NULL;
#if defined(_MSC_VER)
    open_error = (int)fopen_s(&input, path, "rb");
#else
    input = fopen(path, "rb");
    open_error = input == NULL ? errno : 0;
#endif
    if (input == NULL) {
        (void)fprintf(stderr, "%s: error: cannot open source (error %d)\n", path,
                      open_error);
        return 1;
    }
    while (fgets(line, (int)sizeof(line), input) != NULL) {
        size_t index;
        size_t length;
        ++state.line;
        length = strlen(line);
        if (length == sizeof(line) - 1U && line[length - 1U] != '\n') {
            diagnose(&state, length, "line exceeds validator capacity");
            break;
        }
        if (length == 0U || line[length - 1U] != '\n') {
            diagnose(&state, length + 1U, "file must end with a newline");
        } else {
            line[--length] = '\0';
        }
        if (length > 100U) {
            diagnose(&state, 101U, "lines must not exceed 100 columns");
        }
        for (index = 0U; index < length; ++index) {
            unsigned char byte = (unsigned char)line[index];
            if (byte == '\t') {
                diagnose(&state, index + 1U, "tabs are forbidden; use spaces");
            } else if (byte < 32U || byte > 126U) {
                diagnose(&state, index + 1U, "source must contain printable ASCII only");
            }
        }
        if (length > 0U && isspace((unsigned char)line[length - 1U])) {
            diagnose(&state, length, "trailing whitespace is forbidden");
        }
        validate_source_line(&state, line);
    }
    if (ferror(input)) {
        (void)fprintf(stderr, "%s: error: failed while reading source\n", path);
        ++state.errors;
    }
    if (fclose(input) != 0) {
        (void)fprintf(stderr, "%s: error: failed to close source\n", path);
        ++state.errors;
    }
    if (state.main_count != 1U) {
        (void)fprintf(stderr, "%s: error: expected exactly one instruction labeled Main; found %u\n",
                      path, state.main_count);
        ++state.errors;
    }
    if (state.code_origin_count != 1U) {
        (void)fprintf(stderr, "%s: error: expected exactly one LOC #100; found %u\n",
                      path, state.code_origin_count);
        ++state.errors;
    }
    if (state.data_origin_count != 1U) {
        (void)fprintf(stderr, "%s: error: expected exactly one LOC Data_Segment; found %u\n",
                      path, state.data_origin_count);
        ++state.errors;
    }
    if (state.greg_count != 1U) {
        (void)fprintf(stderr, "%s: error: expected exactly one GREG @; found %u\n",
                      path, state.greg_count);
        ++state.errors;
    }
    if (state.pending_exit_line != 0UL) {
        (void)fprintf(stderr,
                      "%s:%lu:9: error: SETL $255,0 must be followed by TRAP 0,Halt,0\n",
                      path, state.pending_exit_line);
        ++state.errors;
    }
    return state.errors == 0U ? 0 : 1;
}

static int self_test_case(const char *source, unsigned int segment,
                          int expect_error) {
    FileState state;
    char line[LINE_CAPACITY];
    size_t length = strlen(source);
    if (length >= sizeof(line)) {
        return 1;
    }
    (void)memcpy(line, source, length + 1U);
    state.path = "<self-test>";
    state.line = 1UL;
    state.errors = 0U;
    state.main_count = 0U;
    state.data_origin_count = 0U;
    state.code_origin_count = 0U;
    state.greg_count = 0U;
    state.segment = segment;
    state.pending_exit_line = 0UL;
    state.quiet = 1;
    validate_source_line(&state, line);
    return (state.errors != 0U) == expect_error ? 0 : 1;
}

static int run_self_tests(void) {
    struct TestCase {
        const char *source;
        unsigned int segment;
        int expect_error;
    };
    static const struct TestCase cases[] = {
        {"Message BYTE    \"100% safe\",0", 1U, 0},
        {"        ADD     GoodReg,GoodReg,1 % hidden $2", 2U, 0},
        {"        ADD     GoodReg,$2,1", 2U, 1},
        {"Bad     IS      $1", 1U, 1},
        {"        SETL    255,1", 2U, 1},
        {"PoolReg GREG    @", 1U, 1},
        {"        ADD     GoodReg,GoodReg,1%bad-comment", 2U, 1},
        {"        BYTE    \"unterminated", 1U, 1}
    };
    size_t index;
    for (index = 0U; index < sizeof(cases) / sizeof(cases[0]); ++index) {
        if (self_test_case(cases[index].source, cases[index].segment,
                           cases[index].expect_error) != 0) {
            (void)fprintf(stderr, "validator self-test %lu failed\n",
                          (unsigned long)(index + 1U));
            return 1;
        }
    }
    (void)printf("validator self-tests passed (%lu cases)\n",
                 (unsigned long)(sizeof(cases) / sizeof(cases[0])));
    return 0;
}

int main(int argc, char **argv) {
    int index;
    int failed = 0;
    if (argc < 2) {
        (void)fprintf(stderr, "usage: %s <source.mms>... | --self-test\n", argv[0]);
        return 2;
    }
    if (argc == 2 && strcmp(argv[1], "--self-test") == 0) {
        return run_self_tests();
    }
    for (index = 1; index < argc; ++index) {
        if (validate_file(argv[index]) != 0) {
            failed = 1;
        }
    }
    return failed;
}
