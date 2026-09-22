#include "guard.h"
#include "project.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifdef _WIN32
#include <windows.h>
#else
#include <unistd.h>
#endif

static char *copy_string(const char *text) {
    size_t size = strlen(text) + 1U;
    char *copy = malloc(size);
    if (copy != NULL)
        memcpy(copy, text, size);
    return copy;
}

static char *environment_value(const char *name, int *failed) {
    char *value;
#ifdef _WIN32
    DWORD required, written, error;
    SetLastError(ERROR_SUCCESS);
    required = GetEnvironmentVariableA(name, NULL, 0U);
    if (required == 0U) {
        error = GetLastError();
        if (error == ERROR_ENVVAR_NOT_FOUND)
            return NULL;
        if (error != ERROR_SUCCESS) {
            *failed = 1;
            return NULL;
        }
        value = copy_string("");
    } else {
        value = malloc((size_t)required);
        if (value != NULL) {
            written = GetEnvironmentVariableA(name, value, required);
            if (written == 0U || written >= required) {
                free(value);
                *failed = 1;
                return NULL;
            }
        }
    }
#else
    const char *original = getenv(name);
    if (original == NULL)
        return NULL;
    value = copy_string(original);
#endif
    if (value == NULL)
        *failed = 1;
    return value;
}

static int executable(const char *path) {
#ifdef _WIN32
    DWORD attributes = GetFileAttributesA(path);
    return attributes != INVALID_FILE_ATTRIBUTES && (attributes & FILE_ATTRIBUTE_DIRECTORY) == 0;
#else
    return access(path, X_OK) == 0;
#endif
}
static int find_command(const char *name) {
    char *path;
    const char *start;
    int result = 0, failed = 0;
#ifdef _WIN32
    const char separator = ';';
#else
    const char separator = ':';
#endif
    if (strchr(name, '/') != NULL || strchr(name, '\\') != NULL)
        return executable(name);
    path = environment_value("PATH", &failed);
    if (failed)
        return -1;
    if (path == NULL)
        return 0;
    start = path;
    for (;;) {
        const char *end = strchr(start, separator);
        size_t length = end == NULL ? strlen(start) : (size_t)(end - start);
        size_t name_length = strlen(name);
        size_t size;
        char *candidate;
        if (length > SIZE_MAX - name_length - 2) {
            result = -1;
            break;
        }
        size = length + name_length + 2;
        candidate = malloc(size);
        int found;
        if (candidate == NULL) {
            result = -1;
            break;
        }
        if (length == 0)
            memcpy(candidate, name, name_length + 1);
        else {
            memcpy(candidate, start, length);
            candidate[length] = '/';
            memcpy(candidate + length + 1, name, name_length + 1);
        }
        found = executable(candidate);
        free(candidate);
        if (found) {
            result = 1;
            break;
        }
        if (end == NULL)
            break;
        start = end + 1;
    }
    free(path);
    return result;
}
char *g_compiler(void) {
    int failed = 0;
    char *override = environment_value("CC", &failed);
    size_t i;
    if (failed)
        return NULL;
#ifdef _WIN32
    static const char *const candidates[] = {"cl.exe"};
#else
    static const char *const candidates[] = {"cc", "clang", "gcc"};
#endif
#ifdef _WIN32
    if (override != NULL && strcmp(override, "cl") == 0) {
        free(override);
        override = copy_string("cl.exe");
        if (override == NULL)
            return NULL;
    }
#endif
    if (override != NULL) {
        if (*override != 0 && find_command(override) > 0)
            return override;
        free(override);
        return NULL;
    }
    for (i = 0; i < sizeof candidates / sizeof candidates[0]; ++i) {
        int found = find_command(candidates[i]);
        if (found < 0)
            return NULL;
        if (found > 0)
            return copy_string(candidates[i]);
    }
    return NULL;
}

static int show_file(const char *path) {
    unsigned char *data;
    size_t size;
    int result = g_read(path, &data, &size);
    if (result != 0)
        return result;
    if (size > 0 && fwrite(data, 1, size, stderr) != size)
        result = g_internal("cannot print child diagnostic");
    free(data);
    return result;
}
static int compile_tool(const char *name, const char *first, const char *second,
                        const char *third) {
    char *compiler = g_compiler();
    const char *args[20];
    size_t n = 0;
    int status, result;
    char output[128], stdout_log[160], stderr_log[160];
    if (compiler == NULL || *compiler == 0) {
        free(compiler);
        return g_internal("no supported C compiler found; check CC and PATH");
    }
    args[n++] = compiler;
#ifdef _WIN32
    args[n++] = "/nologo";
    args[n++] = "/TC";
    args[n++] = "/O2";
    args[n++] = "/Ivendor/mmixware/generated";
    args[n++] = "/Fobuild/bin/";
    (void)snprintf(output, sizeof output, "/Febuild/bin/%s.exe", name);
    args[n++] = output;
#else
    args[n++] = "-std=gnu89";
    args[n++] = "-O2";
    args[n++] = "-Ivendor/mmixware/generated";
    args[n++] = "-o";
    (void)snprintf(output, sizeof output, "build/bin/%s", name);
    args[n++] = output;
#endif
    args[n++] = first;
    if (second != NULL)
        args[n++] = second;
    if (third != NULL)
        args[n++] = third;
    args[n] = NULL;
    (void)snprintf(stdout_log, sizeof stdout_log, "build/tmp/%s-compiler.out", name);
    (void)snprintf(stderr_log, sizeof stderr_log, "build/tmp/%s-compiler.err", name);
    result = g_run(args, NULL, stdout_log, stderr_log, &status, 180);
    if (result != 0) {
        free(compiler);
        return result;
    }
    if (status != 0) {
        result = show_file(stdout_log);
        if (result == 0)
            result = show_file(stderr_log);
        if (result == 0)
            result = g_error("compiler failed for %s (exit %d)", name, status);
        free(compiler);
        return result;
    }
    /* Successful upstream diagnostics remain in per-tool logs; run preserves program streams. */
    free(compiler);
    return 0;
}
int g_build_tools(void) {
    int result = g_vendor();
    if (result == 0)
        result = g_mkdir("build/bin");
    if (result == 0)
        result = g_mkdir("build/tmp");
    if (result == 0)
        result = g_mkdir("build/app");
    if (result == 0)
        result = g_mkdir("build/tests");
    if (result == 0)
        result = g_mkdir("build/profiles");
    if (result == 0)
        result = compile_tool("mmixal", "vendor/mmixware/mmixal.c", "vendor/mmixware/mmix-arith.c",
                              NULL);
    if (result == 0)
        result = compile_tool("mmix", "tools/portability/mmix-host.c",
                              "vendor/mmixware/mmix-arith.c", "vendor/mmixware/mmix-io.c");
    if (result == 0)
        result = compile_tool("mmotype", "vendor/mmixware/mmotype.c", NULL, NULL);
    return result;
}
int g_assemble(const char *entry, const char *stem, int production) {
    const char *modules[] = {entry, "src/lib/parse.mms", "src/lib/format.mms", "src/lib/io.mms"};
    const char *args[7];
    char *source, *listing, *object;
    unsigned char *combined = NULL;
    size_t used = 0, i, length = strlen(stem);
    int result, status;
    (void)production;
    if (length > SIZE_MAX - 5)
        return g_internal("output path too long");
    source = malloc(length + 5);
    listing = malloc(length + 5);
    object = malloc(length + 5);
    if (source == NULL || listing == NULL || object == NULL) {
        free(source);
        free(listing);
        free(object);
        return g_internal("allocation failed");
    }
    (void)snprintf(source, length + 5, "%s.mms", stem);
    (void)snprintf(listing, length + 5, "%s.mml", stem);
    (void)snprintf(object, length + 5, "%s.mmo", stem);
    /* Invalidate previous outputs before validating this source revision. */
    result = g_write(source, "", 0);
    if (result == 0)
        result = g_write(listing, "", 0);
    if (result == 0)
        result = g_write(object, "", 0);
    if (result == 0)
        result = g_source(4, modules);
    if (result != 0)
        goto finish;
    for (i = 0; i < 4; ++i) {
        unsigned char *data, *next;
        size_t size;
        result = g_read(modules[i], &data, &size);
        if (result != 0)
            goto finish;
        if (size > SIZE_MAX - used - 1) {
            free(data);
            result = g_internal("source too large");
            goto finish;
        }
        next = realloc(combined, used + size + 1);
        if (next == NULL) {
            free(data);
            result = g_internal("allocation failed");
            goto finish;
        }
        combined = next;
        memcpy(combined + used, data, size);
        used += size;
        combined[used++] = '\n';
        free(data);
    }
    result = g_write(source, combined, used);
    if (result != 0)
        goto finish;
    args[0] = G_ASSEMBLER;
    args[1] = "-l";
    args[2] = listing;
    args[3] = "-o";
    args[4] = object;
    args[5] = source;
    args[6] = NULL;
    result = g_run(args, NULL, "build/tmp/assembler-out.txt", "build/tmp/assembler-err.txt",
                   &status, 30);
    if (result != 0)
        goto finish;
    if (status != 0) {
        result = show_file("build/tmp/assembler-out.txt");
        if (result == 0)
            result = show_file("build/tmp/assembler-err.txt");
        if (result == 0)
            result = g_error("assembly failed: %s (exit %d)", entry, status);
        goto finish;
    }
    result = g_empty("build/tmp/assembler-out.txt");
    if (result == 0)
        result = g_empty("build/tmp/assembler-err.txt");
    if (result == 0)
        result = g_listing(listing);
    if (result == 0)
        result = g_object(object);
finish:
    free(combined);
    free(source);
    free(listing);
    free(object);
    return result;
}
