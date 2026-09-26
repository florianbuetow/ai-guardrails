#define _POSIX_C_SOURCE 200809L
#include "guard.h"
#include "project.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifdef _WIN32
#include <windows.h>
#else
#include <sys/stat.h>
#include <unistd.h>
#endif

static const char *const production[] = {"src/main.mms", "src/lib/parse.mms", "src/lib/format.mms",
                                         "src/lib/io.mms"};
static int dump(const char *path, FILE *stream) {
    unsigned char *data;
    size_t size;
    int result = g_read(path, &data, &size);
    if (result != 0)
        return result;
    if (size != 0 && fwrite(data, 1, size, stream) != size)
        result = g_internal("cannot print %s", path);
    free(data);
    return result;
}
static int workspace(void) {
    const char *const directories[] = {"build/tmp",   "build/app",      "build/bin",
                                       "build/tests", "build/profiles", "build/ci"};
    size_t i;
    for (i = 0; i < sizeof directories / sizeof directories[0]; ++i) {
        int result = g_mkdir(directories[i]);
        if (result != 0)
            return result;
    }
    return g_write("build/tmp/empty", "", 0);
}
static int initialize(void) {
    const char *const git_init[] = {"git", "init", "-q", NULL};
    const char *const hook_path[] = {"git", "rev-parse", "--git-path", "hooks", NULL};
    const char *const local_hooks[] = {"git",        "config", "--local", "core.hooksPath",
                                       ".git/hooks", NULL};
    const char hook[] = "#!/bin/sh\nset -eu\nexec just ci-quiet\n";
    unsigned char *data;
    size_t size;
    char *path;
    int status, result;
    result = g_mkdir(".git");
    if (result != 0)
        return result;
    result = g_run(git_init, NULL, NULL, NULL, &status, 30);
    if (result != 0 || status != 0)
        return result != 0 ? result : g_error("git init failed");
    result = g_run(local_hooks, NULL, NULL, NULL, &status, 30);
    if (result != 0 || status != 0)
        return result != 0 ? result : g_error("cannot configure the project-local hook path");
    result =
        g_run(hook_path, NULL, "build/tmp/hooks.txt", "build/tmp/hooks-errors.txt", &status, 30);
    if (result != 0 || status != 0)
        return result != 0 ? result : g_error("cannot locate Git hooks");
    result = g_read("build/tmp/hooks.txt", &data, &size);
    if (result != 0)
        return result;
    while (size > 0 && (data[size - 1] == '\n' || data[size - 1] == '\r'))
        data[--size] = 0;
    if (size == 0 || memchr(data, '\n', size) != NULL || memchr(data, 0, size) != NULL) {
        free(data);
        return g_internal("invalid Git hook path");
    }
    if (strcmp((const char *)data, ".git/hooks") != 0 &&
        strcmp((const char *)data, ".git\\hooks") != 0) {
        free(data);
        return g_internal("refusing to install a hook outside the project .git/hooks");
    }
    result = g_mkdir((const char *)data);
    path = malloc(size + 12);
    if (path == NULL) {
        free(data);
        return g_internal("allocation failed");
    }
    (void)snprintf(path, size + 12, "%s/pre-commit", data);
    free(data);
    if (result == 0)
        result = g_write(path, hook, sizeof hook - 1);
#ifndef _WIN32
    if (result == 0 && chmod(path, 0700) != 0)
        result = g_internal("cannot make Git hook executable");
#endif
    free(path);
    if (result == 0)
        result = g_build_tools();
    if (result == 0)
        result = g_assemble("src/main.mms", G_APP, 1);
    if (result == 0)
        result = g_test("tests/cli/success.test");
    return result;
}
int g_selftest(void) {
    uint64_t value;
    int result;
    if (g_u64("18446744073709551615", 10, &value) != 0 || value != UINT64_MAX ||
        g_u64("18446744073709551616", 10, &value) == 0 || g_u64("-1", 10, &value) == 0 ||
        g_u64("ffG", 16, &value) == 0 || g_u64("", 10, &value) == 0)
        return g_error("integer parser self-test failed");
    {
        GConfig config;
        const char *const child[] = {"build/tools/mmix-guard" G_EXE, "process-probe",
                                     "spaces \"quotes\" ; literal", NULL};
        const char expected[] = "spaces \"quotes\" ; literal";
        unsigned char *actual;
        size_t count;
        int status;
        if (g_config_load("tools/guard/fixtures/common-duplicate.conf", &config) == 0) {
            g_config_free(&config);
            return g_error("duplicate keys accepted");
        }
        if (g_config_load("tools/guard/fixtures/common-malformed.conf", &config) == 0) {
            g_config_free(&config);
            return g_error("malformed config accepted");
        }
        result = g_run(child, "build/tmp/empty", "build/tmp/process-test.out",
                       "build/tmp/process-test.err", &status, 5);
        if (result != 0)
            return result;
        if (status != 7)
            return g_error("child exit status was lost");
        result = g_empty("build/tmp/process-test.err");
        if (result != 0)
            return result;
        result = g_read("build/tmp/process-test.out", &actual, &count);
        if (result != 0)
            return result;
        if (count != sizeof expected - 1 || memcmp(actual, expected, count) != 0) {
            free(actual);
            return g_error("argument array forwarding failed");
        }
        free(actual);
    }
    {
        GConfig exits;
        size_t i;
        result = g_config_load("tools/guard/fixtures/process-exits.conf", &exits);
        if (result != 0)
            return result;
        for (i = 0; i < exits.count; ++i) {
            uint64_t expected;
            int status;
            const char *args[] = {"build/tools/mmix-guard" G_EXE, "process-exit", exits.values[i],
                                  NULL};
            if (g_u64(exits.values[i], 10, &expected) != 0 || expected > 255) {
                g_config_free(&exits);
                return g_internal("malformed process exit fixture");
            }
            result = g_run(args, "build/tmp/empty", "build/tmp/process-exit.out",
                           "build/tmp/process-exit.err", &status, 5);
            if (result != 0 || status != (int)expected) {
                g_config_free(&exits);
                return g_error("child exit code contract failed");
            }
        }
        g_config_free(&exits);
    }
    {
        int status;
        const char *missing[] = {"build/tools/missing-tool" G_EXE, NULL};
        const char *slow[] = {"build/tools/mmix-guard" G_EXE, "process-wait", NULL};
        if (g_run(missing, "build/tmp/empty", "build/tmp/process-exit.out",
                  "build/tmp/process-exit.err", &status, 1) != 2)
            return g_error("missing child executable did not fail closed");
        if (g_run(slow, "build/tmp/empty", "build/tmp/process-exit.out",
                  "build/tmp/process-exit.err", &status, 1) != 2)
            return g_error("child timeout did not fail closed");
    }
    result = g_source_selftest();
    if (result == 0)
        result = g_test_selftest();
    if (result == 0)
        result = g_profile_selftest();
    return result;
}
static int check_host(void) {
    char *compiler = g_compiler();
    const char *const git[] = {"git", "--version", NULL};
    const char *const just[] = {"just", "--version", NULL};
#ifdef _WIN32
    const char *cc[] = {compiler, "/?", NULL};
#else
    const char *cc[] = {compiler, "--version", NULL};
#endif
    int result, status;
    if (compiler == NULL)
        return g_error("missing supported C compiler; check CC and PATH");
    result = g_run(git, NULL, NULL, NULL, &status, 15);
    if (result == 0 && status != 0)
        result = g_error("Git prerequisite failed");
    if (result == 0) {
        result = g_run(just, NULL, NULL, NULL, &status, 15);
        if (result == 0 && status != 0)
            result = g_error("just prerequisite failed");
    }
    if (result == 0) {
        result = g_run(cc, NULL, NULL, NULL, &status, 15);
        if (result == 0 && status != 0)
            result = g_error("C compiler prerequisite failed");
    }
    free(compiler);
    return result;
}

static int stage(const char *name) {
    if (strcmp(name, "check") == 0)
        return check_host();
    if (strcmp(name, "code-vendor") == 0)
        return g_vendor();
    if (strcmp(name, "code-style") == 0)
        return g_hygiene(0, NULL);
    if (strcmp(name, "code-source") == 0 || strcmp(name, "code-architecture") == 0)
        return g_source(4, production);
    if (strcmp(name, "code-security") == 0) {
        int result = g_vendor();
        return result != 0 ? result : g_source(4, production);
    }
    if (strcmp(name, "host-tools") == 0)
        return g_build_tools();
    if (strcmp(name, "assemble") == 0)
        return g_assemble("src/main.mms", G_APP, 1);
    if (strcmp(name, "code-object") == 0)
        return g_object(G_APP ".mmo");
    if (strcmp(name, "test-unit") == 0)
        return g_test_all("tests/unit");
    if (strcmp(name, "test-state") == 0)
        return g_test_all("tests/state");
    if (strcmp(name, "test-cli") == 0)
        return g_test_all("tests/cli");
    if (strcmp(name, "coverage") == 0)
        return g_coverage_all();
    if (strcmp(name, "selftest") == 0)
        return g_selftest();
    return g_internal("unknown stage: %s", name);
}
static int pipeline(int quiet) {
    const char *const names[] = {"check",         "code-vendor", "code-style",  "code-source",
                                 "host-tools",    "assemble",    "code-object", "code-architecture",
                                 "code-security", "selftest",    "test-unit",   "test-state",
                                 "test-cli",      "coverage"};
    size_t i;
    for (i = 0; i < sizeof names / sizeof names[0]; ++i) {
        const char *args[] = {"build/tools/mmix-guard" G_EXE, "internal-stage", names[i], NULL};
        char output[128], errors[128];
        int status, result;
        (void)snprintf(output, sizeof output, "build/ci/%s.out", names[i]);
        (void)snprintf(errors, sizeof errors, "build/ci/%s.err", names[i]);
        result = g_run(args, "build/tmp/empty", output, errors, &status, 600);
        if (result != 0)
            return result;
        if (!quiet || status != 0) {
            result = dump(output, stdout);
            if (result == 0)
                result = dump(errors, stderr);
            if (result != 0)
                return result;
        }
        if (status != 0) {
            (void)fprintf(stderr, "\033[31mFAIL %s failed\033[0m\n", names[i]);
            return status == 2 ? 2 : 1;
        }
        (void)printf("\033[32mOK %s passed\033[0m\n", names[i]);
        if (fflush(stdout) != 0)
            return g_internal("cannot flush CI progress");
    }
    (void)printf("All CI checks passed\n");
    return 0;
}
static int runtime(const char *command, int argc, char **argv) {
    const char **args;
    size_t n = 0;
    int i, status, result = g_build_tools();
    if (result == 0)
        result = g_assemble("src/main.mms", G_APP, 1);
    if (result != 0)
        return result;
    args = calloc((size_t)argc + 4, sizeof(char *));
    if (args == NULL)
        return g_internal("allocation failed");
    args[n++] = G_SIMULATOR;
    if (strcmp(command, "debug") == 0)
        args[n++] = "-i";
    args[n++] = G_APP ".mmo";
    for (i = 2; i < argc; ++i)
        args[n++] = argv[i];
    args[n] = NULL;
    result = g_run(args, NULL, NULL, NULL, &status, strcmp(command, "debug") == 0 ? 3600U : 30U);
    free(args);
    return result != 0 ? result : status;
}
static int dispatch(int argc, char **argv) {
    const char *command;
    int result;
    if (argc < 2)
        return g_internal("usage: mmix-guard <command> [arguments]");
    command = argv[1];
    if (strcmp(command, "process-exit") == 0 && argc == 3) {
        uint64_t code;
        if (g_u64(argv[2], 10, &code) != 0 || code > 255)
            return 2;
        return (int)code;
    }
    if (strcmp(command, "process-wait") == 0 && argc == 2) {
#ifdef _WIN32
        Sleep(3000);
#else
        if (sleep(3) != 0)
            return 2;
#endif
        return 0;
    }
    if (strcmp(command, "process-probe") == 0 && argc == 3) {
        (void)printf("%s", argv[2]);
        return 7;
    }
    if (strcmp(command, "help") == 0 && argc == 2) {
        (void)printf("Setup & lifecycle\n  init  check  destroy  help\n\n");
        (void)printf("Build & run\n  build  assemble  run [arguments]  debug [arguments]\n\n");
        (void)printf("Code quality\n  code-style  code-source  code-vendor  code-object\n");
        (void)printf("  code-architecture  code-security\n\n");
        (void)printf("Testing\n  test  test-unit  test-state  test-cli  coverage  selftest\n\n");
        (void)printf("CI\n  ci  ci-quiet\n");
        return 0;
    }
    result = workspace();
    if (result != 0)
        return result;
    if (strcmp(command, "init") == 0 && argc == 2)
        return initialize();
    if (strcmp(command, "internal-stage") == 0 && argc == 3)
        return stage(argv[2]);
    if (strcmp(command, "ci") == 0 && argc == 2)
        return pipeline(0);
    if (strcmp(command, "ci-quiet") == 0 && argc == 2) {
        (void)printf("Running CI Checks (Quiet Mode)\n");
        return pipeline(1);
    }
    if (strcmp(command, "source") == 0 && argc > 2)
        return g_source(argc - 2, (const char *const *)(argv + 2));
    if (strcmp(command, "vendor") == 0 && argc == 2)
        return g_vendor();
    if (strcmp(command, "hygiene") == 0)
        return g_hygiene(argc - 2, (const char *const *)(argv + 2));
    if (strcmp(command, "listing") == 0 && argc == 3)
        return g_listing(argv[2]);
    if (strcmp(command, "object") == 0 && argc == 3)
        return g_object(argv[2]);
    if (strcmp(command, "test") == 0 && argc == 3)
        return g_test(argv[2]);
    if (strcmp(command, "coverage") == 0 && argc == 4)
        return g_coverage(argv[2], argv[3]);
    if (strcmp(command, "run") == 0 || strcmp(command, "debug") == 0)
        return runtime(command, argc, argv);
    if (argc != 2)
        return g_internal("invalid command arguments");
    if (strcmp(command, "code-vendor") == 0 || strcmp(command, "code-style") == 0 ||
        strcmp(command, "code-source") == 0 || strcmp(command, "code-security") == 0 ||
        strcmp(command, "code-architecture") == 0 || strcmp(command, "selftest") == 0)
        return stage(command);
    if (strcmp(command, "build") == 0 || strcmp(command, "assemble") == 0 ||
        strcmp(command, "code-object") == 0 || strcmp(command, "test") == 0 ||
        strcmp(command, "test-unit") == 0 || strcmp(command, "test-state") == 0 ||
        strcmp(command, "test-cli") == 0 || strcmp(command, "coverage") == 0) {
        result = g_build_tools();
        if (result == 0)
            result = g_assemble("src/main.mms", G_APP, 1);
        if (result != 0 || strcmp(command, "build") == 0 || strcmp(command, "assemble") == 0)
            return result;
        if (strcmp(command, "test") == 0) {
            result = stage("test-unit");
            if (result == 0)
                result = stage("test-state");
            if (result == 0)
                result = stage("test-cli");
            return result;
        }
        return stage(command);
    }
    return g_internal("unknown command: %s", command);
}

int main(int argc, char **argv) {
    int result = dispatch(argc, argv);
    if (argc >= 2 && strcmp(argv[1], "run") != 0 && strcmp(argv[1], "debug") != 0 &&
        strcmp(argv[1], "internal-stage") != 0 && strcmp(argv[1], "process-probe") != 0 &&
        strcmp(argv[1], "process-exit") != 0 && strcmp(argv[1], "process-wait") != 0) {
        if (result == 0)
            (void)printf("\033[32m%s passed\033[0m\n", argv[1]);
        else
            (void)fprintf(stderr, "\033[31m%s failed\033[0m\n", argv[1]);
    }
    return result;
}
