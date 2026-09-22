#include "test.h"
#include "guard.h"

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define TEST_TIMEOUT 30U

static int ends_with(const char *text, const char *suffix) {
    size_t text_length = strlen(text);
    size_t suffix_length = strlen(suffix);
    return text_length >= suffix_length && strcmp(text + text_length - suffix_length, suffix) == 0;
}

static const char *base_name(const char *path) {
    const char *base = path;
    const char *cursor;
    for (cursor = path; *cursor != '\0'; ++cursor) {
        if (*cursor == '/' || *cursor == '\\') {
            base = cursor + 1;
        }
    }
    return base;
}

static unsigned long path_hash(const char *path) {
    unsigned long value = 2166136261UL;
    const unsigned char *cursor = (const unsigned char *)path;
    while (*cursor != 0U) {
        value ^= (unsigned long)*cursor++;
        value *= 16777619UL;
    }
    return value;
}

static int temp_path(char *buffer, size_t capacity, const char *test, const char *suffix) {
    int written = snprintf(buffer, capacity, "build/tmp/test-%08lx%s",
                           path_hash(test) & 0xffffffffUL, suffix);
    if (written < 0 || (size_t)written >= capacity) {
        return g_internal("temporary test path is too long");
    }
    return 0;
}

static int expected_bytes(const char *actual, const char *expected, const char *field,
                          const char *test) {
    unsigned char *data = NULL;
    size_t size = 0U;
    int result;
    if (*expected != '\0') {
        result = g_equal(actual, expected);
        if (result != 0) {
            return g_error("%s: %s did not match %s byte-for-byte", test, field, expected);
        }
        return 0;
    }
    result = g_read(actual, &data, &size);
    free(data);
    if (result != 0) {
        return result;
    }
    if (size != 0U) {
        return g_error("%s: expected empty %s, got %zu bytes", test, field, size);
    }
    return 0;
}

static int parse_exit(const char *text, int *value) {
    uint64_t parsed;
    if (g_u64(text, 10U, &parsed) != 0 || parsed > 255U) {
        return g_error("invalid test exit code: %s", text);
    }
    *value = (int)parsed;
    return 0;
}

static int is_state_key(const char *key) {
    return strncmp(key, "register.$", 10U) == 0 || strncmp(key, "special.r", 9U) == 0 ||
           strncmp(key, "memory.", 7U) == 0 || strcmp(key, "pc") == 0 ||
           strcmp(key, "termination") == 0;
}

static int validate_cli_keys(const GConfig *config, const char *path) {
    size_t index;
    size_t next_argument = 1U;
    for (index = 0U; index < config->count; ++index) {
        const char *key = config->keys[index];
        if (strcmp(key, "program") == 0 || strcmp(key, "stdin") == 0 ||
            strcmp(key, "stdout") == 0 || strcmp(key, "stderr") == 0 || strcmp(key, "exit") == 0) {
            continue;
        }
        if (strncmp(key, "arg.", 4U) == 0) {
            uint64_t number;
            if (g_u64(key + 4U, 10U, &number) != 0 || number != next_argument) {
                return g_error("%s: arguments must be consecutive from arg.1", path);
            }
            ++next_argument;
            continue;
        }
        return g_error("%s: unknown CLI test key: %s", path, key);
    }
    return 0;
}

static int repository_path(const char *value, const char *prefix, int allow_empty) {
    const char *segment;
    if (*value == '\0')
        return allow_empty;
    if (strncmp(value, prefix, strlen(prefix)) != 0 || strchr(value, '\\') != NULL ||
        strchr(value, ':') != NULL)
        return 0;
    segment = value;
    for (;;) {
        const char *end = strchr(segment, '/');
        size_t length = end == NULL ? strlen(segment) : (size_t)(end - segment);
        if (length == 0U || (length == 1U && segment[0] == '.') ||
            (length == 2U && segment[0] == '.' && segment[1] == '.'))
            return 0;
        if (end == NULL)
            break;
        segment = end + 1;
    }
    return 1;
}

static int validate_cli_metadata(const GConfig *config, const char *path) {
    const char *program = g_config_get(config, "program");
    const char *input = g_config_get(config, "stdin");
    const char *expected_out = g_config_get(config, "stdout");
    const char *expected_err = g_config_get(config, "stderr");
    const char *exit_text = g_config_get(config, "exit");
    int unused;
    if (program == NULL || input == NULL || expected_out == NULL || expected_err == NULL ||
        exit_text == NULL) {
        return g_error("%s: CLI test requires program, stdin, stdout, stderr, exit", path);
    }
    if (!repository_path(program, "build/", 0) || !ends_with(program, ".mmo") ||
        !repository_path(input, "tests/fixtures/", 1) ||
        !repository_path(expected_out, "tests/fixtures/", 1) ||
        !repository_path(expected_err, "tests/fixtures/", 1)) {
        return g_error("%s: test paths must refer to local build objects and committed fixtures",
                       path);
    }
    if (validate_cli_keys(config, path) != 0 || parse_exit(exit_text, &unused) != 0) {
        return 1;
    }
    return 0;
}

static int run_cli_test(const char *path, const GConfig *config) {
    const char *program = g_config_get(config, "program");
    const char *input = g_config_get(config, "stdin");
    const char *expected_out = g_config_get(config, "stdout");
    const char *expected_err = g_config_get(config, "stderr");
    const char *exit_text = g_config_get(config, "exit");
    const char **arguments;
    char output[128];
    char errors[128];
    size_t argument_count = 0U;
    size_t index;
    int expected_status;
    int status;
    int result;
    if (validate_cli_metadata(config, path) != 0 || parse_exit(exit_text, &expected_status) != 0) {
        return 1;
    }
    while (g_config_get(config, "arg.1") != NULL && argument_count < config->count) {
        char key[40];
        int written = snprintf(key, sizeof(key), "arg.%zu", argument_count + 1U);
        if (written < 0 || (size_t)written >= sizeof(key) || g_config_get(config, key) == NULL) {
            break;
        }
        ++argument_count;
    }
    arguments = (const char **)calloc(argument_count + 4U, sizeof(*arguments));
    if (arguments == NULL) {
        return g_internal("out of memory preparing %s", path);
    }
    arguments[0] = G_SIMULATOR;
    arguments[1] = "-q";
    arguments[2] = program;
    for (index = 0U; index < argument_count; ++index) {
        char key[40];
        (void)snprintf(key, sizeof(key), "arg.%zu", index + 1U);
        arguments[index + 3U] = g_config_get(config, key);
    }
    if (temp_path(output, sizeof(output), path, ".stdout") != 0 ||
        temp_path(errors, sizeof(errors), path, ".stderr") != 0) {
        free(arguments);
        return 2;
    }
    result = g_run(arguments, *input == '\0' ? "build/tmp/empty" : input, output, errors, &status,
                   TEST_TIMEOUT);
    free(arguments);
    if (result != 0) {
        return result;
    }
    if (status != expected_status) {
        return g_error("%s: expected exit %d, got %d", path, expected_status, status);
    }
    if (expected_bytes(output, expected_out, "stdout", path) != 0 ||
        expected_bytes(errors, expected_err, "stderr", path) != 0) {
        return 1;
    }
    return 0;
}

static int special_index(const char *name, unsigned *index) {
    static const char *const names[] = {"rB", "rD", "rE", "rH", "rJ",  "rM",  "rR",  "rBB",
                                        "rC", "rN", "rO", "rS", "rI",  "rT",  "rTT", "rK",
                                        "rQ", "rU", "rV", "rG", "rL",  "rA",  "rF",  "rP",
                                        "rW", "rX", "rY", "rZ", "rWW", "rXX", "rYY", "rZZ"};
    size_t cursor;
    for (cursor = 0U; cursor < sizeof(names) / sizeof(names[0]); ++cursor) {
        if (strcmp(name, names[cursor]) == 0) {
            *index = (unsigned)cursor;
            return 0;
        }
    }
    return g_error("unknown MMIX special register: %s", name);
}

static int append_text(char **text, size_t *length, size_t *capacity, const char *addition) {
    size_t add_length = strlen(addition);
    size_t required;
    char *grown;
    if (add_length > SIZE_MAX - *length - 1U) {
        return g_internal("state command input is too large");
    }
    required = *length + add_length + 1U;
    if (required > *capacity) {
        size_t next = *capacity == 0U ? 256U : *capacity;
        while (next < required) {
            if (next > SIZE_MAX / 2U) {
                next = required;
                break;
            }
            next *= 2U;
        }
        grown = (char *)realloc(*text, next);
        if (grown == NULL) {
            return g_internal("out of memory creating state commands");
        }
        *text = grown;
        *capacity = next;
    }
    memcpy(*text + *length, addition, add_length + 1U);
    *length += add_length;
    return 0;
}

static int state_commands(const GConfig *config, char **commands) {
    size_t length = 0U;
    size_t capacity = 0U;
    size_t index;
    *commands = NULL;
    if (append_text(commands, &length, &capacity, "s\n") != 0) {
        return 2;
    }
    for (index = 0U; index < config->count; ++index) {
        const char *key = config->keys[index];
        char command[96];
        int written = 0;
        if (strncmp(key, "register.$", 10U) == 0) {
            uint64_t number;
            if (g_u64(key + 10U, 10U, &number) != 0 || number > 255U) {
                return g_error("invalid dynamic register in state test: %s", key);
            }
            written = snprintf(command, sizeof(command), "$%llu#\n", (unsigned long long)number);
        } else if (strncmp(key, "special.", 8U) == 0) {
            unsigned unused;
            if (special_index(key + 8U, &unused) != 0) {
                return 1;
            }
            written = snprintf(command, sizeof(command), "%s#\n", key + 8U);
        } else if (strncmp(key, "memory.", 7U) == 0) {
            uint64_t address;
            if (g_u64(key + 7U, 16U, &address) != 0 || (address & UINT64_C(7)) != 0U) {
                return g_error("invalid memory address in state test: %s", key);
            }
            written =
                snprintf(command, sizeof(command), "M%016llx#\n", (unsigned long long)address);
        }
        if (written != 0) {
            if (written < 0 || (size_t)written >= sizeof(command) ||
                append_text(commands, &length, &capacity, command) != 0) {
                return 2;
            }
        }
    }
    if (append_text(commands, &length, &capacity, "q\n") != 0) {
        return 2;
    }
    return 0;
}

static int line_hex_value(const char *line, const char *label, uint64_t *value) {
    const char *found;
    char digits[17];
    size_t index;
    if (label[0] == '(') {
        found = strstr(line, label);
    } else if (strncmp(line, "mmix> ", 6U) == 0 &&
               strncmp(line + 6U, label, strlen(label)) == 0) {
        found = line + 6U;
    } else {
        found = NULL;
    }
    if (found == NULL) {
        return 0;
    }
    found += strlen(label);
    {
        const char *hex = strchr(found, '#');
        if (hex != NULL) {
            found = hex + 1;
        }
    }
    for (index = 0U; index < 16U && isxdigit((unsigned char)found[index]); ++index) {
        digits[index] = found[index];
    }
    if (index == 0U || index > 16U) {
        return -1;
    }
    digits[index] = '\0';
    if (found[index] != '\0' && found[index] != '\r' && found[index] != '\n' &&
        found[index] != ')' && !isspace((unsigned char)found[index])) {
        return -1;
    }
    return g_u64(digits, 16U, value) == 0 ? 1 : -1;
}

static int find_state_value(const unsigned char *output, size_t size, const char *label,
                            uint64_t *value) {
    size_t start = 0U;
    int matches = 0;
    uint64_t first = 0U;
    while (start < size) {
        size_t end = start;
        char *line;
        int parsed;
        while (end < size && output[end] != '\n') {
            ++end;
        }
        line = (char *)malloc(end - start + 1U);
        if (line == NULL) {
            return -2;
        }
        memcpy(line, output + start, end - start);
        line[end - start] = '\0';
        parsed = line_hex_value(line, label, value);
        free(line);
        if (parsed < 0) {
            return -1;
        }
        if (parsed > 0) {
            if (matches == 0) {
                first = *value;
            } else if (*value != first) {
                return -1;
            }
            ++matches;
        }
        start = end < size ? end + 1U : end;
    }
    if (matches > 0) {
        *value = first;
        return 0;
    }
    return -1;
}

static int verify_state_output(const char *path, const GConfig *config, const char *output_path) {
    unsigned char *output = NULL;
    size_t size = 0U;
    size_t index;
    int result = g_read(output_path, &output, &size);
    if (result != 0) {
        return result;
    }
    for (index = 0U; index < config->count; ++index) {
        const char *key = config->keys[index];
        const char *expected_text = config->values[index];
        char label[96];
        uint64_t expected;
        uint64_t actual;
        int written = 0;
        if (!is_state_key(key)) {
            continue;
        }
        if (strcmp(key, "termination") == 0) {
            if (strcmp(expected_text, "halted") != 0 ||
                strstr((const char *)output, "(halted at location #") == NULL) {
                free(output);
                return g_error("%s: expected termination=halted", path);
            }
            continue;
        }
        if (strcmp(key, "pc") == 0) {
            const char *marker = strstr((const char *)output, "(halted at location #");
            if (marker == NULL) {
                free(output);
                return g_error("%s: missing exact halted program counter", path);
            }
            written = snprintf(label, sizeof(label), "(halted at location #");
        } else if (strncmp(key, "register.$", 10U) == 0) {
            written = snprintf(label, sizeof(label), "$%s=", key + 10U);
        } else if (strncmp(key, "special.", 8U) == 0) {
            unsigned special;
            if (special_index(key + 8U, &special) != 0) {
                free(output);
                return 1;
            }
            written = snprintf(label, sizeof(label), "g[%u]=", special);
        } else if (strncmp(key, "memory.", 7U) == 0) {
            uint64_t address;
            if (g_u64(key + 7U, 16U, &address) != 0 || (address & UINT64_C(7)) != 0U) {
                free(output);
                return g_error("%s: invalid memory expectation %s", path, key);
            }
            written = snprintf(label, sizeof(label), "M8[#%016llx]=",
                               (unsigned long long)address);
        }
        if (written < 0 || (size_t)written >= sizeof(label) ||
            g_u64(expected_text, 16U, &expected) != 0 ||
            find_state_value(output, size, label, &actual) != 0) {
            free(output);
            return g_error("%s: malformed or missing exact state value for %s", path, key);
        }
        if (actual != expected) {
            free(output);
            return g_error("%s: %s expected %016llx, got %016llx", path, key,
                           (unsigned long long)expected, (unsigned long long)actual);
        }
    }
    free(output);
    return 0;
}

static int run_state_test(const char *path, const GConfig *config) {
    const char *program = g_config_get(config, "program");
    const char *run = g_config_get(config, "run");
    const char **arguments;
    char command_path[128];
    char output[128];
    char errors[128];
    char *commands = NULL;
    int status;
    int result;
    size_t index;
    size_t argument_count = 0U;
    size_t expectations = 0U;
    if (program == NULL || run == NULL || strcmp(run, "until-halt") != 0 ||
        !repository_path(program, "build/", 0) || !ends_with(program, ".mmo")) {
        return g_error("%s: state test requires program and run=until-halt", path);
    }
    for (index = 0U; index < config->count; ++index) {
        const char *key = config->keys[index];
        if (strcmp(key, "program") != 0 && strcmp(key, "run") != 0 &&
            strncmp(key, "arg.", 4U) != 0 && !is_state_key(key)) {
            return g_error("%s: unknown state test key: %s", path, key);
        }
        if (is_state_key(key)) {
            ++expectations;
        }
    }
    if (expectations == 0U || g_config_get(config, "termination") == NULL) {
        return g_error("%s: state test requires expectations and termination", path);
    }
    for (;;) {
        char key[40];
        (void)snprintf(key, sizeof(key), "arg.%zu", argument_count + 1U);
        if (g_config_get(config, key) == NULL) {
            break;
        }
        ++argument_count;
    }
    for (index = 0U; index < config->count; ++index) {
        if (strncmp(config->keys[index], "arg.", 4U) == 0) {
            uint64_t number;
            if (g_u64(config->keys[index] + 4U, 10U, &number) != 0 || number == 0U ||
                number > argument_count) {
                return g_error("%s: state arguments must be consecutive from arg.1", path);
            }
        }
    }
    if (state_commands(config, &commands) != 0 ||
        temp_path(command_path, sizeof(command_path), path, ".commands") != 0 ||
        temp_path(output, sizeof(output), path, ".state") != 0 ||
        temp_path(errors, sizeof(errors), path, ".stderr") != 0) {
        free(commands);
        return 2;
    }
    result = g_write(command_path, commands, strlen(commands));
    free(commands);
    if (result != 0) {
        return result;
    }
    arguments = (const char **)calloc(argument_count + 4U, sizeof(*arguments));
    if (arguments == NULL) {
        return g_internal("out of memory preparing state test");
    }
    arguments[0] = G_SIMULATOR;
    arguments[1] = "-I";
    arguments[2] = program;
    for (index = 0U; index < argument_count; ++index) {
        char key[40];
        (void)snprintf(key, sizeof(key), "arg.%zu", index + 1U);
        arguments[index + 3U] = g_config_get(config, key);
    }
    result = g_run(arguments, command_path, output, errors, &status, TEST_TIMEOUT);
    free(arguments);
    if (result != 0) {
        return result;
    }
    if (status != 0 || expected_bytes(errors, "", "stderr", path) != 0) {
        return g_error("%s: simulator failed during state inspection", path);
    }
    return verify_state_output(path, config, output);
}

int g_test(const char *path) {
    GConfig config;
    int state;
    int result = g_config_load(path, &config);
    if (result != 0) {
        return result;
    }
    state = g_config_get(&config, "run") != NULL;
    result = state ? run_state_test(path, &config) : run_cli_test(path, &config);
    g_config_free(&config);
    return result;
}

static int run_unit(const char *path) {
    const char *name = base_name(path);
    char stem[256];
    char object[272];
    char listing[272];
    char output[128];
    char errors[128];
    const char *arguments[4];
    size_t length = strlen(name);
    int written;
    int status;
    if (length <= 4U || !ends_with(name, ".mms")) {
        return 0;
    }
    written = snprintf(stem, sizeof(stem), "build/tests/%.*s", (int)(length - 4U), name);
    if (written < 0 || (size_t)written >= sizeof(stem)) {
        return g_internal("unit test output path too long: %s", path);
    }
    if (g_assemble(path, stem, 0) != 0) {
        return 1;
    }
    (void)snprintf(object, sizeof(object), "%s.mmo", stem);
    (void)snprintf(listing, sizeof(listing), "%s.mml", stem);
    if (g_listing(listing) != 0 || g_object(object) != 0 ||
        temp_path(output, sizeof(output), path, ".stdout") != 0 ||
        temp_path(errors, sizeof(errors), path, ".stderr") != 0) {
        return 1;
    }
    arguments[0] = G_SIMULATOR;
    arguments[1] = "-q";
    arguments[2] = object;
    arguments[3] = NULL;
    if (g_run(arguments, "build/tmp/empty", output, errors, &status, TEST_TIMEOUT) != 0) {
        return 2;
    }
    if (status != 0) {
        return g_error("unit test %s failed with exit %d", path, status);
    }
    return expected_bytes(errors, "", "stderr", path);
}

int g_test_all(const char *directory) {
    GPaths paths;
    size_t index;
    size_t ran = 0U;
    int result = g_list(directory, &paths);
    if (result != 0) {
        return result;
    }
    for (index = 0U; index < paths.count; ++index) {
        const char *path = paths.items[index];
        if (ends_with(path, ".mms")) {
            ++ran;
            result = run_unit(path);
        } else if (ends_with(path, ".test")) {
            ++ran;
            result = g_test(path);
        } else {
            continue;
        }
        if (result != 0) {
            g_paths_free(&paths);
            return result;
        }
    }
    g_paths_free(&paths);
    if (ran == 0U) {
        return g_error("no tests found in %s", directory);
    }
    return 0;
}

int g_test_selftest(void) {
    if (repository_path("../escape", "build/", 0) ||
        repository_path("build/../escape.mmo", "build/", 0) ||
        repository_path("-Ddump.mmb", "build/", 0) || repository_path("", "build/", 0)) {
        return g_error("self-test: external/option-injected object path accepted");
    }
    static const char *const rejected[] = {"tools/guard/fixtures/test-missing.test",
                                           "tools/guard/fixtures/test-unknown.test",
                                           "tools/guard/fixtures/test-argument-gap.test",
                                           "tools/guard/fixtures/test-invalid-exit.test"};
    GConfig config;
    size_t index;
    int result = g_config_load("tools/guard/fixtures/test-valid.test", &config);
    if (result != 0) {
        return result;
    }
    result = validate_cli_metadata(&config, "test-valid.test");
    g_config_free(&config);
    if (result != 0) {
        return result;
    }
    result = g_config_load("tools/guard/fixtures/test-duplicate.test", &config);
    if (result == 0) {
        g_config_free(&config);
        return g_error("self-test: duplicate test keys were accepted");
    }
    result = g_config_load("tools/guard/fixtures/test-malformed.test", &config);
    if (result == 0) {
        g_config_free(&config);
        return g_error("self-test: malformed test metadata was accepted");
    }
    for (index = 0U; index < sizeof(rejected) / sizeof(rejected[0]); ++index) {
        result = g_config_load(rejected[index], &config);
        if (result != 0) {
            return result;
        }
        result = validate_cli_metadata(&config, rejected[index]);
        g_config_free(&config);
        if (result == 0) {
            return g_error("self-test: invalid test metadata was accepted: %s", rejected[index]);
        }
    }
    return 0;
}
