#define _POSIX_C_SOURCE 200809L
#include "guard.h"
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifdef _WIN32
#include <windows.h>

static HANDLE redirected(const char *path, DWORD access, DWORD disposition, DWORD standard) {
    SECURITY_ATTRIBUTES security;
    if (path == NULL)
        return GetStdHandle(standard);
    security.nLength = (DWORD)sizeof security;
    security.lpSecurityDescriptor = NULL;
    security.bInheritHandle = TRUE;
    return CreateFileA(path, access, FILE_SHARE_READ | FILE_SHARE_WRITE, &security, disposition,
                       FILE_ATTRIBUTE_NORMAL, NULL);
}
static char *command_line(const char *const argv[]) {
    size_t size = 1, i, at = 0;
    char *line;
    for (i = 0; argv[i] != NULL; ++i) {
        size_t n = strlen(argv[i]);
        if (n > (SIZE_MAX - size - 4) / 2)
            return NULL;
        size += n * 2 + 4;
    }
    line = malloc(size);
    if (line == NULL)
        return NULL;
    for (i = 0; argv[i] != NULL; ++i) {
        const char *p = argv[i];
        if (i != 0)
            line[at++] = ' ';
        line[at++] = '"';
        while (*p != 0) {
            size_t slashes = 0, j;
            while (*p == '\\') {
                ++slashes;
                ++p;
            }
            if (*p == '"' || *p == 0) {
                for (j = 0; j < slashes * 2; ++j)
                    line[at++] = '\\';
                if (*p == '"') {
                    line[at++] = '\\';
                    line[at++] = *p++;
                }
            } else {
                for (j = 0; j < slashes; ++j)
                    line[at++] = '\\';
                line[at++] = *p++;
            }
        }
        line[at++] = '"';
    }
    line[at] = 0;
    return line;
}
int g_run(const char *const argv[], const char *input, const char *output, const char *errors,
          int *status, unsigned timeout_seconds) {
    STARTUPINFOA startup;
    PROCESS_INFORMATION process;
    HANDLE in, out, err, job;
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits;
    DWORD waited, code;
    int result = 0;
    char *line;
    if (argv == NULL || argv[0] == NULL || timeout_seconds == 0 || timeout_seconds > 3600)
        return g_internal("invalid process request");
    line = command_line(argv);
    if (line == NULL)
        return g_internal("command allocation failed");
    in = redirected(input, GENERIC_READ, OPEN_EXISTING, STD_INPUT_HANDLE);
    out = redirected(output, GENERIC_WRITE, CREATE_ALWAYS, STD_OUTPUT_HANDLE);
    err = redirected(errors, GENERIC_WRITE, CREATE_ALWAYS, STD_ERROR_HANDLE);
    if (in == INVALID_HANDLE_VALUE || out == INVALID_HANDLE_VALUE || err == INVALID_HANDLE_VALUE) {
        result = g_internal("cannot open process redirection for %s", argv[0]);
        goto cleanup;
    }
    memset(&startup, 0, sizeof startup);
    memset(&process, 0, sizeof process);
    startup.cb = (DWORD)sizeof startup;
    startup.dwFlags = STARTF_USESTDHANDLES;
    startup.hStdInput = in;
    startup.hStdOutput = out;
    startup.hStdError = err;
    job = CreateJobObjectA(NULL, NULL);
    if (job == NULL) {
        result = g_internal("cannot create process job");
        goto cleanup;
    }
    memset(&limits, 0, sizeof limits);
    limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
    if (!SetInformationJobObject(job, JobObjectExtendedLimitInformation, &limits,
                                 (DWORD)sizeof limits)) {
        (void)CloseHandle(job);
        result = g_internal("cannot configure process job");
        goto cleanup;
    }
    if (!CreateProcessA(NULL, line, NULL, NULL, TRUE, CREATE_SUSPENDED, NULL, NULL, &startup,
                        &process)) {
        result = g_internal("cannot execute %s (Windows error %lu)", argv[0],
                            (unsigned long)GetLastError());
        (void)CloseHandle(job);
        goto cleanup;
    }
    if (!AssignProcessToJobObject(job, process.hProcess) ||
        ResumeThread(process.hThread) == (DWORD)-1) {
        if (!TerminateProcess(process.hProcess, 2) ||
            WaitForSingleObject(process.hProcess, 5000) != WAIT_OBJECT_0)
            result = g_internal("cannot terminate failed child startup");
        else
            result = g_internal("cannot start child process");
    } else {
        waited = WaitForSingleObject(process.hProcess, timeout_seconds * 1000UL);
        if (waited != WAIT_OBJECT_0) {
            if (!TerminateJobObject(job, 2) ||
                WaitForSingleObject(process.hProcess, 5000) != WAIT_OBJECT_0)
                result = g_internal("cannot terminate timed out process: %s", argv[0]);
            else
                result = g_internal("process timeout or wait failure: %s", argv[0]);
        } else if (!GetExitCodeProcess(process.hProcess, &code) || code > 255) {
            result = g_internal("unexpected process termination: %s", argv[0]);
        } else
            *status = (int)code;
    }
    (void)CloseHandle(process.hThread);
    (void)CloseHandle(process.hProcess);
    (void)CloseHandle(job);
cleanup:
    if (input != NULL && in != INVALID_HANDLE_VALUE)
        (void)CloseHandle(in);
    if (output != NULL && out != INVALID_HANDLE_VALUE)
        (void)CloseHandle(out);
    if (errors != NULL && err != INVALID_HANDLE_VALUE)
        (void)CloseHandle(err);
    free(line);
    return result;
}
#else
#include <fcntl.h>
#include <signal.h>
#include <spawn.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>
extern char **environ;

static int stop_child(pid_t child) {
    int code;
    if (kill(-child, SIGKILL) != 0 && errno != ESRCH)
        return g_internal("cannot terminate child process");
    for (;;) {
        if (waitpid(child, &code, 0) == child || errno == ECHILD)
            return 0;
        if (errno != EINTR)
            return g_internal("cannot reap child process");
    }
}

int g_run(const char *const argv[], const char *input, const char *output, const char *errors,
          int *status, unsigned timeout_seconds) {
    pid_t child;
    struct timespec start;
    posix_spawn_file_actions_t actions;
    posix_spawnattr_t attributes;
    int result, closed_actions, closed_attributes;
    if (argv == NULL || argv[0] == NULL || timeout_seconds == 0 || timeout_seconds > 3600)
        return g_internal("invalid process request");
    if (clock_gettime(CLOCK_MONOTONIC, &start) != 0)
        return g_internal("cannot read monotonic clock");
    result = posix_spawn_file_actions_init(&actions);
    if (result != 0)
        return g_internal("cannot initialize child redirections");
    result = posix_spawnattr_init(&attributes);
    if (result != 0) {
        (void)posix_spawn_file_actions_destroy(&actions);
        return g_internal("cannot initialize child attributes");
    }
    result = posix_spawnattr_setflags(&attributes, POSIX_SPAWN_SETPGROUP);
    if (result == 0)
        result = posix_spawnattr_setpgroup(&attributes, 0);
    if (result == 0 && input != NULL)
        result = posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, input, O_RDONLY, 0600);
    if (result == 0 && output != NULL)
        result = posix_spawn_file_actions_addopen(&actions, STDOUT_FILENO, output,
                                                  O_WRONLY | O_CREAT | O_TRUNC, 0600);
    if (result == 0 && errors != NULL)
        result = posix_spawn_file_actions_addopen(&actions, STDERR_FILENO, errors,
                                                  O_WRONLY | O_CREAT | O_TRUNC, 0600);
    if (result == 0)
        result = posix_spawnp(&child, argv[0], &actions, &attributes, (char *const *)argv, environ);
    closed_actions = posix_spawn_file_actions_destroy(&actions);
    closed_attributes = posix_spawnattr_destroy(&attributes);
    if (result != 0)
        return g_internal("cannot execute %s (error %d)", argv[0], result);
    if (closed_actions != 0 || closed_attributes != 0) {
        if (stop_child(child) != 0)
            return 2;
        return g_internal("cannot release child setup resources");
    }
    for (;;) {
        int code;
        pid_t done = waitpid(child, &code, WNOHANG);
        struct timespec now, delay = {0, 10000000};
        if (done == child) {
            if (!WIFEXITED(code))
                return g_internal("unexpected process termination: %s", argv[0]);
            *status = WEXITSTATUS(code);
            return 0;
        }
        if (done < 0 && errno != EINTR) {
            if (stop_child(child) != 0)
                return 2;
            return g_internal("cannot wait for %s", argv[0]);
        }
        if (clock_gettime(CLOCK_MONOTONIC, &now) != 0 ||
            now.tv_sec - start.tv_sec >= (time_t)timeout_seconds) {
            if (stop_child(child) != 0)
                return 2;
            return g_internal("process timeout: %s", argv[0]);
        }
        while (nanosleep(&delay, &delay) != 0) {
            if (errno != EINTR) {
                if (stop_child(child) != 0)
                    return 2;
                return g_internal("process wait clock failed");
            }
        }
    }
}
#endif
