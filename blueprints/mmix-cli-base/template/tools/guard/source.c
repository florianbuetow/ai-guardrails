#include "source.h"
#include "guard.h"
#include "sha256.h"

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    SourceSet labels;
    SourceSet owned_labels;
    SourceSet references;
    SourceSet traps;
    SourceSet specials;
    SourceSet uses255;
    SourceSet forbidden;
    unsigned main_count;
    unsigned data_loc_count;
    unsigned code_loc_count;
    unsigned errors;
    int production;
    size_t max_line;
    uint64_t magic_min;
    unsigned scratch_first;
    unsigned scratch_last;
    const char *io_module;
} SourceState;

static const char *const operations[] = {
    "TRAP",  "FCMP",   "FUN",    "FEQL",   "FADD",   "FIX",   "FSUB",  "FIXU",  "FLOT",  "FLOTU",
    "SFLOT", "SFLOTU", "FMUL",   "FCMPE",  "FUNE",   "FEQLE", "FDIV",  "FSQRT", "FREM",  "FINT",
    "MUL",   "MULU",   "DIV",    "DIVU",   "ADD",    "ADDU",  "SUB",   "SUBU",  "2ADDU", "4ADDU",
    "8ADDU", "16ADDU", "CMP",    "CMPU",   "NEG",    "NEGU",  "SL",    "SLU",   "SR",    "SRU",
    "BN",    "BZ",     "BP",     "BOD",    "BNN",    "BNZ",   "BNP",   "BEV",   "PBN",   "PBZ",
    "PBP",   "PBOD",   "PBNN",   "PBNZ",   "PBNP",   "PBEV",  "CSN",   "CSZ",   "CSP",   "CSOD",
    "CSNN",  "CSNZ",   "CSNP",   "CSEV",   "ZSN",    "ZSZ",   "ZSP",   "ZSOD",  "ZSNN",  "ZSNZ",
    "ZSNP",  "ZSEV",   "LDB",    "LDBU",   "LDW",    "LDWU",  "LDT",   "LDTU",  "LDO",   "LDOU",
    "LDSF",  "LDHT",   "CSWAP",  "LDUNC",  "LDVTS",  "PRELD", "PREGO", "GO",    "STB",   "STBU",
    "STW",   "STWU",   "STT",    "STTU",   "STO",    "STOU",  "STSF",  "STHT",  "STCO",  "STUNC",
    "SYNCD", "PREST",  "SYNCID", "PUSHGO", "OR",     "ORN",   "NOR",   "XOR",   "AND",   "ANDN",
    "NAND",  "NXOR",   "BDIF",   "WDIF",   "TDIF",   "ODIF",  "MUX",   "SADD",  "MOR",   "MXOR",
    "SETH",  "SETMH",  "SETML",  "SETL",   "INCH",   "INCMH", "INCML", "INCL",  "ORH",   "ORMH",
    "ORML",  "ORL",    "ANDNH",  "ANDNMH", "ANDNML", "ANDNL", "JMP",   "PUSHJ", "GETA",  "PUT",
    "POP",   "RESUME", "SAVE",   "UNSAVE", "SYNC",   "SWYM",  "GET",   "TRIP",  "SET",   "LDA"};
static const char *const directives[] = {"IS",   "LOC",   "GREG", "BYTE",
                                         "WYDE", "TETRA", "OCTA", "PREFIX"};
static const char *const branches[] = {"BN",   "BZ",   "BP",   "BOD",  "BNN", "BNZ",
                                       "BNP",  "BEV",  "PBN",  "PBZ",  "PBP", "PBOD",
                                       "PBNN", "PBNZ", "PBNP", "PBEV", "JMP", "PUSHJ"};

static int set_add(SourceSet *set, const char *value, int unique) {
    char **grown;
    char *copy;
    size_t index;
    for (index = 0U; index < set->count; ++index) {
        if (strcmp(set->items[index], value) == 0)
            return unique ? 1 : 0;
    }
    if (set->count == SIZE_MAX / sizeof(*set->items))
        return 2;
    grown = (char **)realloc(set->items, (set->count + 1U) * sizeof(*set->items));
    if (grown == NULL)
        return 2;
    set->items = grown;
    size_t length = strlen(value);
    copy = (char *)malloc(length + 1U);
    if (copy == NULL)
        return 2;
    (void)memcpy(copy, value, length + 1U);
    set->items[set->count++] = copy;
    return 0;
}

void source_set_free(SourceSet *set) {
    size_t index;
    for (index = 0U; index < set->count; ++index)
        free(set->items[index]);
    free(set->items);
    set->items = NULL;
    set->count = 0U;
}

static int member(const char *value, const char *const values[], size_t count) {
    size_t index;
    for (index = 0U; index < count; ++index)
        if (strcmp(value, values[index]) == 0)
            return 1;
    return 0;
}

static char *strip(char *text) {
    char *end;
    while (*text != '\0' && isspace((unsigned char)*text))
        ++text;
    end = text + strlen(text);
    while (end > text && isspace((unsigned char)end[-1]))
        --end;
    *end = '\0';
    return text;
}

static void uppercase(char *text) {
    while (*text != '\0') {
        *text = (char)toupper((unsigned char)*text);
        ++text;
    }
}

static int has_prefix(const char *text, const char *prefix) {
    return strncmp(text, prefix, strlen(prefix)) == 0;
}

static int parse_uint_config(const GConfig *config, const char *key, uint64_t minimum,
                             uint64_t maximum, uint64_t *result) {
    const char *text = g_config_get(config, key);
    uint64_t value;
    if (text == NULL || g_u64(text, 10U, &value) != 0 || value < minimum || value > maximum)
        return g_internal("config/guardrails.conf: invalid or missing %s", key);
    *result = value;
    return 0;
}

static int load_lines(const char *path, SourceSet *set) {
    unsigned char *data;
    size_t size, offset = 0U;
    int result = g_read(path, &data, &size);
    if (result != 0)
        return result;
    while (offset < size) {
        size_t start = offset, length;
        char *line;
        while (offset < size && data[offset] != '\n')
            ++offset;
        length = offset - start;
        if (length > 0U && data[start + length - 1U] == '\r')
            --length;
        line = (char *)malloc(length + 1U);
        if (line == NULL) {
            free(data);
            return g_internal("out of memory reading %s", path);
        }
        (void)memcpy(line, data + start, length);
        line[length] = '\0';
        if (*strip(line) != '\0' && *strip(line) != '#') {
            result = set_add(set, strip(line), 1);
            if (result == 1)
                result = g_internal("%s: duplicate entry: %s", path, strip(line));
            else if (result == 2)
                result = g_internal("out of memory reading %s", path);
            if (result != 0) {
                free(line);
                free(data);
                return result;
            }
        }
        free(line);
        if (offset < size)
            ++offset;
    }
    free(data);
    return 0;
}

static int load_csv(const char *path, const char *key, const char *text, SourceSet *set) {
    size_t start = 0U, offset = 0U, length = strlen(text);
    if (length == 0U)
        return g_internal("%s: %s must not be empty", path, key);
    while (offset <= length) {
        if (offset == length || text[offset] == ',') {
            size_t item_length = offset - start;
            char *item;
            int result;
            if (item_length == 0U)
                return g_internal("%s: malformed comma list for %s", path, key);
            item = (char *)malloc(item_length + 1U);
            if (item == NULL)
                return g_internal("out of memory");
            (void)memcpy(item, text + start, item_length);
            item[item_length] = '\0';
            if (!member(item, operations, sizeof(operations) / sizeof(operations[0]))) {
                result = g_internal("%s: unknown instruction %s in %s", path, item, key);
            } else {
                result = set_add(set, item, 1);
                if (result == 1)
                    result = g_internal("%s: duplicate instruction %s in %s", path, item, key);
                else if (result == 2)
                    result = g_internal("out of memory");
            }
            free(item);
            if (result != 0)
                return result;
            start = offset + 1U;
        }
        ++offset;
    }
    return 0;
}

static int exact_sets(const char *name, const SourceSet *used, const SourceSet *allowed) {
    size_t index, other;
    int found;
    for (index = 0U; index < used->count; ++index) {
        found = 0;
        for (other = 0U; other < allowed->count; ++other)
            if (strcmp(used->items[index], allowed->items[other]) == 0)
                found = 1;
        if (!found)
            return g_error("%s is used but absent from its exact allowlist: %s", name,
                           used->items[index]);
    }
    for (index = 0U; index < allowed->count; ++index) {
        found = 0;
        for (other = 0U; other < used->count; ++other)
            if (strcmp(allowed->items[index], used->items[other]) == 0)
                found = 1;
        if (!found)
            return g_error("%s allowlist contains stale permission: %s", name,
                           allowed->items[index]);
    }
    return 0;
}

static int set_contains(const SourceSet *set, const char *value) {
    size_t index;
    for (index = 0U; index < set->count; ++index)
        if (strcmp(set->items[index], value) == 0)
            return 1;
    return 0;
}

static int is_suppression(const char *line) {
    static const char *const words[] = {"nosemgrep",  "nolint",        "ignore-next-line",
                                        "skip-check", "allow_failure", "disable_check"};
    char *copy;
    size_t index;
    int found = 0;
    size_t length = strlen(line);
    copy = (char *)malloc(length + 1U);
    if (copy == NULL)
        return -1;
    (void)memcpy(copy, line, length + 1U);
    for (index = 0U; copy[index] != '\0'; ++index)
        copy[index] = (char)tolower((unsigned char)copy[index]);
    for (index = 0U; index < sizeof(words) / sizeof(words[0]); ++index)
        if (strstr(copy, words[index]) != NULL)
            found = 1;
    free(copy);
    return found;
}

static int parse_register_policy(SourceState *state, const char *path, size_t line_number,
                                 const char *operation, const char *operands) {
    const char *cursor = operands;
    while ((cursor = strchr(cursor, '$')) != NULL) {
        char *end;
        unsigned long number;
        if (!isdigit((unsigned char)cursor[1])) {
            ++cursor;
            continue;
        }
        number = strtoul(cursor + 1, &end, 10);
        if (number > 255UL) {
            ++state->errors;
            (void)g_error("%s:%lu: register outside $0..$255", path, (unsigned long)line_number);
        } else if (number == 255UL) {
            char entry[2048];
            if ((size_t)snprintf(entry, sizeof(entry), "%s|%s|%s", path, operation, operands) >=
                sizeof(entry))
                return g_internal("%s:%lu: capability entry too long", path,
                                  (unsigned long)line_number);
            if (set_add(&state->uses255, entry, 0) == 2)
                return g_internal("out of memory");
        } else if (strcmp(operation, "IS") != 0 &&
                   (number < state->scratch_first || number > state->scratch_last)) {
            ++state->errors;
            (void)g_error("%s:%lu: raw register $%lu is outside the documented scratch region",
                          path, (unsigned long)line_number, number);
        }
        cursor = end;
    }
    return 0;
}

static int check_magic(SourceState *state, const char *path, size_t line_number,
                       const char *operation, const char *operands) {
    const char *cursor = operands;
    if (member(operation, directives, sizeof(directives) / sizeof(directives[0])))
        return 0;
    while ((cursor = strchr(cursor, '#')) != NULL) {
        char token[32];
        size_t length = 0U;
        uint64_t value;
        ++cursor;
        while (isxdigit((unsigned char)cursor[length]) && length + 1U < sizeof(token))
            ++length;
        if (length == 0U || isxdigit((unsigned char)cursor[length])) {
            ++cursor;
            continue;
        }
        (void)memcpy(token, cursor, length);
        token[length] = '\0';
        if (g_u64(token, 16U, &value) != 0)
            return g_internal("%s:%lu: malformed hexadecimal value", path,
                              (unsigned long)line_number);
        if (value >= state->magic_min) {
            ++state->errors;
            (void)g_error("%s:%lu: suspicious literal address #%s must be symbolic", path,
                          (unsigned long)line_number, token);
        }
        cursor += length;
    }
    return 0;
}

static int parse_line(SourceState *state, const char *path, size_t line_number, char *line) {
    char *comment = NULL, *cursor, *label = NULL, *operation, *operands;
    int quoted = 0, instruction, directive, result;
    size_t index;
    result = is_suppression(line);
    if (result < 0)
        return g_internal("out of memory");
    if (result != 0) {
        ++state->errors;
        (void)g_error("%s:%lu: checker suppression marker is forbidden", path,
                      (unsigned long)line_number);
    }
    for (index = 0U; line[index] != '\0'; ++index) {
        if (line[index] == '"')
            quoted = !quoted;
        else if (line[index] == '%' && !quoted) {
            comment = line + index;
            break;
        }
    }
    if (comment != NULL)
        *comment = '\0';
    cursor = strip(line);
    if (*cursor == '\0')
        return 0;
    if (!isspace((unsigned char)line[0])) {
        label = cursor;
        while (*cursor != '\0' && !isspace((unsigned char)*cursor))
            ++cursor;
        if (*cursor == '\0') {
            ++state->errors;
            return g_error("%s:%lu: label has no operation", path, (unsigned long)line_number);
        }
        *cursor++ = '\0';
        cursor = strip(cursor);
    }
    operation = cursor;
    while (*cursor != '\0' && !isspace((unsigned char)*cursor))
        ++cursor;
    if (*cursor != '\0')
        *cursor++ = '\0';
    uppercase(operation);
    operands = strip(cursor);
    instruction = member(operation, operations, sizeof(operations) / sizeof(operations[0]));
    directive = member(operation, directives, sizeof(directives) / sizeof(directives[0]));
    if (!instruction && !directive) {
        ++state->errors;
        return g_error("%s:%lu: unknown MMIX operation %s", path, (unsigned long)line_number,
                       operation);
    }
    if (instruction && set_contains(&state->forbidden, operation)) {
        ++state->errors;
        (void)g_error("%s:%lu: forbidden instruction %s", path, (unsigned long)line_number,
                      operation);
    }
    if (*operands == '\0' && strcmp(operation, "SWYM") != 0) {
        ++state->errors;
        return g_error("%s:%lu: %s requires operands", path, (unsigned long)line_number, operation);
    }
    if (label != NULL && strcmp(label, "Main") == 0) {
        if (!instruction) {
            ++state->errors;
            (void)g_error("%s:%lu: Main must label an instruction", path,
                          (unsigned long)line_number);
        } else
            ++state->main_count;
    }
    if (strcmp(operation, "LOC") == 0) {
        if (strcmp(path, "src/main.mms") != 0 && state->production) {
            ++state->errors;
            (void)g_error("%s:%lu: LOC is restricted to src/main.mms", path,
                          (unsigned long)line_number);
        }
        if (strcmp(operands, "Data_Segment") == 0)
            ++state->data_loc_count;
        else if (strcmp(operands, "#100") == 0)
            ++state->code_loc_count;
        else {
            ++state->errors;
            (void)g_error("%s:%lu: LOC must be Data_Segment or #100", path,
                          (unsigned long)line_number);
        }
    }
    if (state->production && (strcmp(operation, "GREG") == 0 || strcmp(operation, "IS") == 0) &&
        strcmp(path, "src/main.mms") != 0) {
        ++state->errors;
        (void)g_error("%s:%lu: %s declarations belong in src/main.mms", path,
                      (unsigned long)line_number, operation);
    }
    if (label != NULL && label[0] != ':' && !isdigit((unsigned char)label[0])) {
        result = set_add(&state->labels, label, 1);
        if (result == 1) {
            ++state->errors;
            (void)g_error("%s:%lu: duplicate label %s", path, (unsigned long)line_number, label);
        } else if (result == 2)
            return g_internal("out of memory");
        else {
            char owned[2048];
            if ((size_t)snprintf(owned, sizeof(owned), "%s|%s", path, label) >= sizeof(owned))
                return g_internal("%s:%lu: label ownership entry too long", path,
                                  (unsigned long)line_number);
            if (set_add(&state->owned_labels, owned, 0) == 2)
                return g_internal("out of memory");
        }
    }
    if (state->production && member(operation, branches, sizeof(branches) / sizeof(branches[0]))) {
        const char *target = strrchr(operands, ',');
        char reference[2048];
        target = target == NULL ? operands : target + 1;
        if ((size_t)snprintf(reference, sizeof(reference), "%s|%s", path, target) >=
            sizeof(reference))
            return g_internal("%s:%lu: control-flow reference too long", path,
                              (unsigned long)line_number);
        if (set_add(&state->references, reference, 0) == 2)
            return g_internal("out of memory");
    }
    result = parse_register_policy(state, path, line_number, operation, operands);
    if (result != 0)
        return result;
    result = check_magic(state, path, line_number, operation, operands);
    if (result != 0)
        return result;
    if (strcmp(operation, "TRAP") == 0) {
        char entry[2048];
        if (!state->production)
            return 0;
        if (strcmp(path, state->io_module) != 0) {
            ++state->errors;
            (void)g_error("%s:%lu: only %s may use TRAP", path, (unsigned long)line_number,
                          state->io_module);
        }
        if ((size_t)snprintf(entry, sizeof(entry), "%s|%s", path, operands) >= sizeof(entry))
            return g_internal("capability entry too long");
        if (set_add(&state->traps, entry, 0) == 2)
            return g_internal("out of memory");
    }
    if (strcmp(operation, "GET") == 0 || strcmp(operation, "PUT") == 0) {
        char entry[2048], *special = operands, *comma = strchr(operands, ',');
        if (!state->production)
            return 0;
        if (strcmp(operation, "GET") == 0) {
            if (comma == NULL) {
                ++state->errors;
                return g_error("%s:%lu: malformed GET", path, (unsigned long)line_number);
            }
            special = comma + 1;
        } else if (comma != NULL)
            *comma = '\0';
        if ((size_t)snprintf(entry, sizeof(entry), "%s|%s|%s", path, operation, strip(special)) >=
            sizeof(entry))
            return g_internal("capability entry too long");
        if (set_add(&state->specials, entry, 0) == 2)
            return g_internal("out of memory");
    }
    return 0;
}

static int validate_file(SourceState *state, const char *path) {
    unsigned char *data;
    size_t size, offset = 0U, line_number = 0U;
    int result = g_read(path, &data, &size);
    if (result != 0)
        return result;
    if (strlen(path) < 4U || strcmp(path + strlen(path) - 4U, ".mms") != 0) {
        free(data);
        return g_error("%s: source path must end in .mms", path);
    }
    while (offset < size) {
        size_t start = offset, length;
        char *line;
        while (offset < size && data[offset] != '\n')
            ++offset;
        length = offset - start;
        ++line_number;
        if (length > 0U && data[start + length - 1U] == '\r')
            --length;
        line = (char *)malloc(length + 1U);
        if (line == NULL) {
            free(data);
            return g_internal("out of memory");
        }
        (void)memcpy(line, data + start, length);
        line[length] = '\0';
        result = parse_line(state, path, line_number, line);
        free(line);
        if (result == 2) {
            free(data);
            return result;
        }
        if (offset < size)
            ++offset;
    }
    free(data);
    return 0;
}

int g_source(int count, const char *const paths[]) {
    SourceState state;
    GConfig config = {0};
    SourceSet allowed_traps = {0}, allowed_specials = {0}, allowed255 = {0};
    uint64_t value;
    int index, result = 0;
    (void)memset(&state, 0, sizeof(state));
    if (count <= 0)
        return g_internal("source requires at least one .mms path");
    state.production = 1;
    for (index = 0; index < count; ++index)
        if (!has_prefix(paths[index], "src/"))
            state.production = 0;
    if (state.production) {
        static const char *const expected[] = {"src/main.mms", "src/lib/parse.mms",
                                               "src/lib/format.mms", "src/lib/io.mms"};
        if (count != 4) {
            (void)g_error("production composition requires exactly four explicit modules");
            ++state.errors;
        } else
            for (index = 0; index < 4; ++index)
                if (strcmp(paths[index], expected[index]) != 0) {
                    (void)g_error("production module %d must be %s", index + 1, expected[index]);
                    ++state.errors;
                }
    }
    result = g_config_load("config/guardrails.conf", &config);
    if (result != 0)
        goto done;
    if (config.count != 6U) {
        result = g_internal("config/guardrails.conf: expected exactly six recognized keys");
        goto done;
    }
    if (parse_uint_config(&config, "max_line_length", 40U, 10000U, &value) != 0) {
        result = 2;
        goto done;
    }
    state.max_line = (size_t)value;
    if (parse_uint_config(&config, "magic_address_min", 1U, UINT64_MAX, &state.magic_min) != 0) {
        result = 2;
        goto done;
    }
    if (parse_uint_config(&config, "scratch_register_first", 0U, 254U, &value) != 0) {
        result = 2;
        goto done;
    }
    state.scratch_first = (unsigned)value;
    if (parse_uint_config(&config, "scratch_register_last", state.scratch_first, 254U, &value) !=
        0) {
        result = 2;
        goto done;
    }
    state.scratch_last = (unsigned)value;
    state.io_module = g_config_get(&config, "io_module");
    if (state.io_module == NULL || state.io_module[0] == '\0') {
        result = g_internal("config/guardrails.conf: missing io_module");
        goto done;
    }
    {
        const char *forbidden = g_config_get(&config, "forbidden_instructions");
        if (forbidden == NULL) {
            result = g_internal("config/guardrails.conf: missing forbidden_instructions");
            goto done;
        }
        result = load_csv("config/guardrails.conf", "forbidden_instructions", forbidden,
                          &state.forbidden);
        if (result != 0)
            goto done;
    }
    for (index = 0; index < count; ++index) {
        result = validate_file(&state, paths[index]);
        if (result == 2)
            goto done;
    }
    if (state.main_count != 1U) {
        (void)g_error("source composition must define Main exactly once; found %u",
                      state.main_count);
        ++state.errors;
    }
    if (state.production) {
        size_t reference_index;
        for (reference_index = 0U; reference_index < state.references.count; ++reference_index) {
            const char *reference = state.references.items[reference_index];
            const char *separator = strchr(reference, '|');
            const char *target = separator == NULL ? "" : separator + 1;
            size_t owner_index;
            const char *owner = NULL;
            for (owner_index = 0U; owner_index < state.owned_labels.count; ++owner_index) {
                const char *owned_separator = strchr(state.owned_labels.items[owner_index], '|');
                if (owned_separator != NULL && strcmp(owned_separator + 1, target) == 0) {
                    owner = state.owned_labels.items[owner_index];
                    break;
                }
            }
            if (owner == NULL) {
                (void)g_error("unresolved static control-flow target: %s", reference);
                ++state.errors;
            } else if (separator != NULL &&
                       (strncmp(reference, "src/lib/parse.mms|", 18U) == 0 ||
                        strncmp(reference, "src/lib/format.mms|", 19U) == 0) &&
                       strncmp(owner, "src/lib/io.mms|", 15U) == 0) {
                (void)g_error("pure module may not call or branch into I/O code: %s", reference);
                ++state.errors;
            }
        }
        if (state.data_loc_count != 1U || state.code_loc_count != 1U) {
            (void)g_error(
                "production source requires exactly one LOC Data_Segment and one LOC #100");
            ++state.errors;
        }
        if ((result = load_lines("config/allowed-traps.txt", &allowed_traps)) != 0 ||
            (result = load_lines("config/allowed-special-registers.txt", &allowed_specials)) != 0 ||
            (result = load_lines("config/allowed-255.txt", &allowed255)) != 0)
            goto done;
        if (exact_sets("TRAP", &state.traps, &allowed_traps) != 0)
            ++state.errors;
        if (exact_sets("special-register", &state.specials, &allowed_specials) != 0)
            ++state.errors;
        if (exact_sets("$255", &state.uses255, &allowed255) != 0)
            ++state.errors;
    }
    result = state.errors == 0U ? 0 : 1;
done:
    source_set_free(&state.labels);
    source_set_free(&state.owned_labels);
    source_set_free(&state.references);
    source_set_free(&state.traps);
    source_set_free(&state.specials);
    source_set_free(&state.uses255);
    source_set_free(&state.forbidden);
    source_set_free(&allowed_traps);
    source_set_free(&allowed_specials);
    source_set_free(&allowed255);
    g_config_free(&config);
    return result;
}

static int valid_utf8(const unsigned char *data, size_t size) {
    size_t i = 0U, need;
    uint32_t code, minimum;
    while (i < size) {
        if (data[i] < 0x80U) {
            ++i;
            continue;
        }
        if ((data[i] & 0xe0U) == 0xc0U) {
            need = 1U;
            code = data[i] & 0x1fU;
            minimum = 0x80U;
        } else if ((data[i] & 0xf0U) == 0xe0U) {
            need = 2U;
            code = data[i] & 0x0fU;
            minimum = 0x800U;
        } else if ((data[i] & 0xf8U) == 0xf0U) {
            need = 3U;
            code = data[i] & 0x07U;
            minimum = 0x10000U;
        } else
            return 0;
        if (i + need >= size)
            return 0;
        while (need-- > 0U) {
            ++i;
            if ((data[i] & 0xc0U) != 0x80U)
                return 0;
            code = (code << 6U) | (data[i] & 0x3fU);
        }
        if (code < minimum || code > 0x10ffffU || (code >= 0xd800U && code <= 0xdfffU))
            return 0;
        ++i;
    }
    return 1;
}

static int hygiene_bytes_clean(const unsigned char *data, size_t size, size_t max_line) {
    size_t index, column = 0U;
    if (size == 0U || data[size - 1U] != '\n' || memchr(data, 0, size) != NULL ||
        !valid_utf8(data, size))
        return 0;
    for (index = 0U; index < size; ++index) {
        ++column;
        if (data[index] == '\r' || data[index] == '\t')
            return 0;
        if (data[index] == '\n') {
            if ((index > 0U && (data[index - 1U] == ' ' || data[index - 1U] == '\t' ||
                                data[index - 1U] == '\r')) ||
                column - 1U > max_line)
                return 0;
            column = 0U;
        }
    }
    return 1;
}

static int hygiene_file(const char *path, size_t max_line) {
    unsigned char *data;
    size_t size, index, line = 1U, column = 0U;
    int errors = 0, result = g_read(path, &data, &size);
    if (result != 0)
        return result;
    if (memchr(data, 0, size) != NULL) {
        (void)g_error("%s: NUL byte", path);
        ++errors;
    }
    if (!valid_utf8(data, size)) {
        (void)g_error("%s: malformed UTF-8", path);
        ++errors;
    }
    if (size > 0U && data[size - 1U] != '\n') {
        (void)g_error("%s: missing final newline", path);
        ++errors;
    }
    for (index = 0U; index < size; ++index) {
        ++column;
        if (data[index] == '\r') {
            (void)g_error("%s:%lu: CRLF/CR is forbidden", path, (unsigned long)line);
            ++errors;
        }
        if (data[index] == '\t') {
            (void)g_error("%s:%lu: tab is forbidden", path, (unsigned long)line);
            ++errors;
        }
        if (data[index] == '\n') {
            if (index > 0U &&
                (data[index - 1U] == ' ' || data[index - 1U] == '\t' || data[index - 1U] == '\r')) {
                (void)g_error("%s:%lu: trailing whitespace", path, (unsigned long)line);
                ++errors;
            }
            if (column - 1U > max_line) {
                (void)g_error("%s:%lu: line exceeds %lu bytes", path, (unsigned long)line,
                              (unsigned long)max_line);
                ++errors;
            }
            ++line;
            column = 0U;
        }
    }
    free(data);
    return errors == 0 ? 0 : 1;
}

static int ascii_casecmp(const char *left, const char *right) {
    while (*left != '\0' && *right != '\0') {
        int a = tolower((unsigned char)*left++), b = tolower((unsigned char)*right++);
        if (a != b)
            return a - b;
    }
    return (unsigned char)*left - (unsigned char)*right;
}

int g_hygiene(int count, const char *const paths[]) {
    GPaths listed = {0};
    GConfig config = {0};
    SourceSet allowed_exceptions = {0}, used_exceptions = {0};
    const char *const *items = paths;
    size_t item_count = (size_t)(count < 0 ? 0 : count), i, j;
    uint64_t maximum;
    int result, errors = 0;
    if (count == 0) {
        result = g_list(".", &listed);
        if (result != 0)
            return result;
        items = (const char *const *)listed.items;
        item_count = listed.count;
    }
    result = g_config_load("config/guardrails.conf", &config);
    if (result != 0) {
        g_paths_free(&listed);
        return result;
    }
    if (parse_uint_config(&config, "max_line_length", 40U, 10000U, &maximum) != 0) {
        g_config_free(&config);
        g_paths_free(&listed);
        return 2;
    }
    result = load_lines("config/hygiene-fixtures.txt", &allowed_exceptions);
    if (result != 0) {
        source_set_free(&allowed_exceptions);
        g_config_free(&config);
        g_paths_free(&listed);
        return result;
    }
    for (i = 0U; i < allowed_exceptions.count; ++i) {
        if (!has_prefix(allowed_exceptions.items[i], "tools/guard/fixtures/")) {
            errors = g_internal("hygiene fixture exception is outside the parser corpus: %s",
                                allowed_exceptions.items[i]);
            goto done;
        }
    }
    for (i = 0U; i < item_count; ++i) {
        const char *path = items[i];
        size_t length = strlen(path);
        if (has_prefix(path, "./"))
            path += 2;
        if (has_prefix(path, ".git/") || has_prefix(path, "build/") || has_prefix(path, "vendor/"))
            continue;
        if (set_contains(&allowed_exceptions, path)) {
            if (set_add(&used_exceptions, path, 0) == 2) {
                errors = g_internal("out of memory");
                goto done;
            }
            continue;
        }
        if (has_prefix(path, "src/") &&
            (length >= 4U &&
             (strcmp(path + length - 4U, ".mmo") == 0 || strcmp(path + length - 4U, ".mml") == 0 ||
              strcmp(path + length - 4U, ".obj") == 0))) {
            (void)g_error("%s: generated artifact in source tree", path);
            ++errors;
            continue;
        }
        result = hygiene_file(path, (size_t)maximum);
        if (result == 2) {
            errors = 2;
            break;
        }
        if (result != 0)
            ++errors;
        for (j = 0U; j < i; ++j)
            if (ascii_casecmp(path, items[j]) == 0 && strcmp(path, items[j]) != 0) {
                (void)g_error("case-colliding paths: %s and %s", path, items[j]);
                ++errors;
            }
    }
    if (count == 0 && errors != 2 &&
        exact_sets("hygiene fixture", &used_exceptions, &allowed_exceptions) != 0)
        ++errors;
done:
    g_config_free(&config);
    g_paths_free(&listed);
    source_set_free(&allowed_exceptions);
    source_set_free(&used_exceptions);
    return errors == 0 ? 0 : (errors == 2 ? 2 : 1);
}

int g_source_selftest(void) {
    static const unsigned char valid[] = {0x61, 0x73, 0x63, 0x69, 0x69, 0xc3, 0xa9};
    static const unsigned char invalid[] = {0xc0, 0x80};
    unsigned char *fixture;
    size_t fixture_size, offset = 0U, cases = 0U;
    int result;
    SourceState parser_state;
    if (!valid_utf8(valid, sizeof(valid)) || valid_utf8(invalid, sizeof(invalid)))
        return g_error("source self-test: UTF-8 parser failed");
    if (g_sha256_selftest() != 0)
        return g_error("source self-test: SHA-256 failed");
    result = g_read("tools/guard/fixtures/source-hygiene.cases", &fixture, &fixture_size);
    if (result != 0)
        return result;
    while (offset < fixture_size) {
        size_t start = offset, first, second, hex_length, byte_count, index;
        unsigned char *bytes;
        int expected_failure;
        while (offset < fixture_size && fixture[offset] != '\n')
            ++offset;
        first = start;
        while (first < offset && fixture[first] != '|')
            ++first;
        second = first + 1U;
        while (second < offset && fixture[second] != '|')
            ++second;
        if (first == offset || second == offset || second != first + 2U ||
            (fixture[first + 1U] != '0' && fixture[first + 1U] != '1')) {
            free(fixture);
            return g_internal("source-hygiene.cases: malformed expected-status manifest");
        }
        expected_failure = fixture[first + 1U] == '1';
        hex_length = offset - second - 1U;
        if ((hex_length & 1U) != 0U) {
            free(fixture);
            return g_internal("source-hygiene.cases: odd hexadecimal fixture");
        }
        byte_count = hex_length / 2U;
        bytes = (unsigned char *)malloc(byte_count == 0U ? 1U : byte_count);
        if (bytes == NULL) {
            free(fixture);
            return g_internal("out of memory");
        }
        for (index = 0U; index < byte_count; ++index) {
            unsigned high = fixture[second + 1U + index * 2U];
            unsigned low = fixture[second + 2U + index * 2U];
            high = high >= '0' && high <= '9'   ? high - '0'
                   : high >= 'a' && high <= 'f' ? high - 'a' + 10U
                                                : 16U;
            low = low >= '0' && low <= '9'   ? low - '0'
                  : low >= 'a' && low <= 'f' ? low - 'a' + 10U
                                             : 16U;
            if (high > 15U || low > 15U) {
                free(bytes);
                free(fixture);
                return g_internal("source-hygiene.cases: invalid hexadecimal fixture");
            }
            bytes[index] = (unsigned char)((high << 4U) | low);
        }
        if (hygiene_bytes_clean(bytes, byte_count, 120U) == expected_failure) {
            free(bytes);
            free(fixture);
            return g_error("source self-test case %lu produced the wrong status",
                           (unsigned long)(cases + 1U));
        }
        free(bytes);
        ++cases;
        if (offset < fixture_size)
            ++offset;
    }
    free(fixture);
    if (cases != 9U)
        return g_internal("source-hygiene.cases: expected nine cases");
    (void)memset(&parser_state, 0, sizeof(parser_state));
    parser_state.scratch_first = 0U;
    parser_state.scratch_last = 15U;
    parser_state.magic_min = 4096U;
    result = validate_file(&parser_state, "tools/guard/fixtures/source-valid.mms");
    if (result != 0 || parser_state.errors != 0U || parser_state.main_count != 1U) {
        source_set_free(&parser_state.labels);
        source_set_free(&parser_state.owned_labels);
        return g_error("source self-test: valid comments/whitespace fixture failed");
    }
    source_set_free(&parser_state.labels);
    source_set_free(&parser_state.owned_labels);
    (void)memset(&parser_state, 0, sizeof(parser_state));
    parser_state.scratch_first = 0U;
    parser_state.scratch_last = 15U;
    parser_state.magic_min = 4096U;
    result = validate_file(&parser_state, "tools/guard/fixtures/source-duplicate-label.mms");
    source_set_free(&parser_state.labels);
    source_set_free(&parser_state.owned_labels);
    if (result == 2)
        return result;
    if (parser_state.errors == 0U)
        return g_error("source self-test: duplicate label fixture passed");
    (void)printf("source parser self-tests passed\n");
    return 0;
}
