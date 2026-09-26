#define _POSIX_C_SOURCE 200809L
#include "guard.h"
#include <errno.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#ifdef _WIN32
#include <direct.h>
#include <windows.h>
#else
#include <dirent.h>
#include <unistd.h>
#endif

void g_diagnostic(const char *format, ...) {
    va_list args;
    va_start(args, format);
    (void)fprintf(stderr, "mmix-guard: ");
    (void)vfprintf(stderr, format, args);
    (void)fputc('\n', stderr);
    va_end(args);
}
static FILE *open_file(const char *path, const char *mode) {
    FILE *file;
#ifdef _MSC_VER
    if (fopen_s(&file, path, mode) != 0)
        return NULL;
#else
    file = fopen(path, mode);
#endif
    return file;
}
int g_read(const char *path, unsigned char **data, size_t *size) {
    FILE *file = open_file(path, "rb");
    size_t used = 0, capacity = 4096;
    unsigned char *buffer;
    *data = NULL;
    *size = 0;
    if (file == NULL)
        return g_internal("cannot read %s (error %d)", path, errno);
    buffer = malloc(capacity);
    if (buffer == NULL) {
        (void)fclose(file);
        return g_internal("allocation failed");
    }
    for (;;) {
        size_t got, requested;
        if (used == capacity - 1) {
            unsigned char *next;
            if (capacity > SIZE_MAX / 2) {
                free(buffer);
                (void)fclose(file);
                return g_internal("input too large: %s", path);
            }
            capacity *= 2;
            next = realloc(buffer, capacity);
            if (next == NULL) {
                free(buffer);
                (void)fclose(file);
                return g_internal("allocation failed");
            }
            buffer = next;
        }
        requested = capacity - used - 1;
        got = fread(buffer + used, 1, requested, file);
        used += got;
        if (got < requested) {
            int failed = ferror(file);
            int ended = feof(file);
            int closed = fclose(file);
            if (failed || !ended || closed != 0) {
                free(buffer);
                return g_internal("read failed: %s", path);
            }
            break;
        }
    }
    buffer[used] = 0;
    *data = buffer;
    *size = used;
    return 0;
}
int g_write(const char *path, const void *data, size_t size) {
    FILE *file = open_file(path, "wb");
    int failed;
    if (file == NULL)
        return g_internal("cannot write %s (error %d)", path, errno);
    failed = fwrite(data, 1, size, file) != size;
    if (fclose(file) != 0)
        failed = 1;
    return failed ? g_internal("write failed: %s", path) : 0;
}
static int make_one(const char *path) {
    int result;
#ifdef _WIN32
    result = _mkdir(path);
#else
    result = mkdir(path, 0700);
#endif
    if (result != 0) {
#ifdef _WIN32
        DWORD attributes = GetFileAttributesA(path);
        if (errno != EEXIST || attributes == INVALID_FILE_ATTRIBUTES ||
            (attributes & FILE_ATTRIBUTE_DIRECTORY) == 0 ||
            (attributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0)
#else
        struct stat info;
        if (errno != EEXIST || lstat(path, &info) != 0 || !S_ISDIR(info.st_mode))
#endif
            return g_internal("cannot create directory %s", path);
    }
    return 0;
}
int g_mkdir(const char *path) {
    size_t length = strlen(path), i;
    char *copy = malloc(length + 1);
    int result = 0;
    if (copy == NULL)
        return g_internal("allocation failed");
    memcpy(copy, path, length + 1);
    for (i = 1; i <= length; ++i) {
        if (copy[i] == '/' || copy[i] == '\0') {
            char saved = copy[i];
            copy[i] = 0;
            result = make_one(copy);
            copy[i] = saved;
            if (result != 0)
                break;
        }
    }
    free(copy);
    return result;
}
static int add_path(GPaths *paths, const char *path) {
    char **next;
    char *copy;
    size_t length = strlen(path);
    if (paths->count >= SIZE_MAX / sizeof(char *) - 1)
        return g_internal("too many paths");
    copy = malloc(length + 1);
    if (copy == NULL)
        return g_internal("allocation failed");
    memcpy(copy, path, length + 1);
    next = realloc(paths->items, (paths->count + 1) * sizeof(char *));
    if (next == NULL) {
        free(copy);
        return g_internal("allocation failed");
    }
    paths->items = next;
    paths->items[paths->count++] = copy;
    return 0;
}
static int walk(const char *directory, GPaths *paths) {
    int result = 0;
#ifdef _WIN32
    WIN32_FIND_DATAA info;
    HANDLE handle;
    size_t length = strlen(directory);
    char *pattern = malloc(length + 3);
    if (pattern == NULL)
        return g_internal("allocation failed");
    (void)snprintf(pattern, length + 3, "%s/*", directory);
    handle = FindFirstFileA(pattern, &info);
    free(pattern);
    if (handle == INVALID_HANDLE_VALUE)
        return g_internal("cannot list %s", directory);
    do {
        const char *name = info.cFileName;
#else
    DIR *handle = opendir(directory);
    struct dirent *entry;
    if (handle == NULL)
        return g_internal("cannot list %s", directory);
    errno = 0;
    while ((entry = readdir(handle)) != NULL) {
        const char *name = entry->d_name;
#endif
        char *path;
        size_t size;
        int is_directory;
#ifndef _WIN32
        struct stat info;
#endif
        if (strcmp(name, ".") == 0 || strcmp(name, "..") == 0)
            continue;
        if (strcmp(directory, ".") == 0 &&
            (strcmp(name, ".git") == 0 || strcmp(name, "build") == 0))
            continue;
        size = strlen(directory) + strlen(name) + 2;
        path = malloc(size);
        if (path == NULL) {
            result = g_internal("allocation failed");
            break;
        }
        if (strcmp(directory, ".") == 0)
            (void)snprintf(path, size, "%s", name);
        else
            (void)snprintf(path, size, "%s/%s", directory, name);
#ifdef _WIN32
        is_directory = (info.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0;
        if ((info.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0)
            result = g_error("unexpected symbolic link or reparse point: %s", path);
#else
        if (lstat(path, &info) != 0) {
            free(path);
            result = g_internal("cannot stat path");
            break;
        }
        is_directory = S_ISDIR(info.st_mode);
        if (S_ISLNK(info.st_mode))
            result = g_error("unexpected symbolic link: %s", path);
#endif
        if (result == 0)
            result = is_directory ? walk(path, paths) : add_path(paths, path);
        free(path);
        if (result != 0)
            break;
#ifndef _WIN32
        errno = 0;
#endif
#ifdef _WIN32
    } while (FindNextFileA(handle, &info));
    if (result == 0 && GetLastError() != ERROR_NO_MORE_FILES)
        result = g_internal("directory read failed: %s", directory);
    if (!FindClose(handle) && result == 0)
        result = g_internal("directory close failed");
#else
    }
    if (result == 0 && errno != 0)
        result = g_internal("directory read failed: %s", directory);
    if (closedir(handle) != 0 && result == 0)
        result = g_internal("directory close failed");
#endif
    return result;
}
static int path_compare(const void *left, const void *right) {
    return strcmp(*(const char *const *)left, *(const char *const *)right);
}
int g_list(const char *directory, GPaths *paths) {
    int result;
    paths->items = NULL;
    paths->count = 0;
    result = walk(directory, paths);
    if (result != 0) {
        g_paths_free(paths);
        return result;
    }
    if (paths->count > 1)
        qsort(paths->items, paths->count, sizeof(char *), path_compare);
    return 0;
}
void g_paths_free(GPaths *paths) {
    size_t i;
    for (i = 0; i < paths->count; ++i)
        free(paths->items[i]);
    free(paths->items);
    paths->items = NULL;
    paths->count = 0;
}
int g_u64(const char *text, unsigned base, uint64_t *value) {
    uint64_t result = 0;
    size_t i;
    if ((base != 10 && base != 16) || text[0] == 0)
        return 2;
    for (i = 0; text[i] != 0; ++i) {
        unsigned digit;
        unsigned char c = (unsigned char)text[i];
        if (c >= '0' && c <= '9')
            digit = (unsigned)(c - '0');
        else if (c >= 'a' && c <= 'f')
            digit = (unsigned)(c - 'a') + 10;
        else if (c >= 'A' && c <= 'F')
            digit = (unsigned)(c - 'A') + 10;
        else
            return 2;
        if (digit >= base || result > (UINT64_MAX - digit) / base)
            return 2;
        result = result * base + digit;
    }
    *value = result;
    return 0;
}
const char *g_config_get(const GConfig *config, const char *key) {
    size_t i;
    for (i = 0; i < config->count; ++i)
        if (strcmp(config->keys[i], key) == 0)
            return config->values[i];
    return NULL;
}
void g_config_free(GConfig *config) {
    size_t i;
    for (i = 0; i < config->count; ++i) {
        free(config->keys[i]);
        free(config->values[i]);
    }
    free(config->keys);
    free(config->values);
    config->keys = NULL;
    config->values = NULL;
    config->count = 0;
}
int g_config_load(const char *path, GConfig *config) {
    unsigned char *data;
    size_t size, start = 0, i;
    int result;
    config->keys = NULL;
    config->values = NULL;
    config->count = 0;
    result = g_read(path, &data, &size);
    if (result != 0)
        return result;
    if (memchr(data, 0, size) != NULL) {
        free(data);
        return g_internal("NUL in configuration %s", path);
    }
    for (i = 0; i <= size; ++i) {
        if (i == size || data[i] == '\n') {
            char *line = (char *)data + start;
            char *separator;
            data[i] = 0;
            if (i > start && data[i - 1] == '\r')
                data[i - 1] = 0;
            start = i + 1;
            if (*line == 0 || *line == '#')
                continue;
            separator = strchr(line, '=');
            if (separator == NULL || separator == line || strchr(line, '\t') != NULL) {
                result = g_internal("malformed key=value in %s", path);
                break;
            }
            *separator++ = 0;
            if (strchr(line, ' ') != NULL || g_config_get(config, line) != NULL) {
                result = g_internal("duplicate or invalid key %s in %s", line, path);
                break;
            }
            {
                char **keys;
                char **values;
                char *key;
                char *value;
                if (config->count >= SIZE_MAX / sizeof(char *) - 1) {
                    result = g_internal("too many keys");
                    break;
                }
                key = malloc(strlen(line) + 1);
                value = malloc(strlen(separator) + 1);
                if (key == NULL || value == NULL) {
                    free(key);
                    free(value);
                    result = g_internal("allocation failed");
                    break;
                }
                memcpy(key, line, strlen(line) + 1);
                memcpy(value, separator, strlen(separator) + 1);
                keys = realloc(config->keys, (config->count + 1) * sizeof(char *));
                if (keys == NULL) {
                    free(key);
                    free(value);
                    result = g_internal("allocation failed");
                    break;
                }
                config->keys = keys;
                values = realloc(config->values, (config->count + 1) * sizeof(char *));
                if (values == NULL) {
                    free(key);
                    free(value);
                    result = g_internal("allocation failed");
                    break;
                }
                config->values = values;
                config->keys[config->count] = key;
                config->values[config->count++] = value;
            }
        }
    }
    free(data);
    if (result != 0)
        g_config_free(config);
    return result;
}
int g_empty(const char *path) {
    unsigned char *data;
    size_t size;
    int result = g_read(path, &data, &size);
    if (result != 0)
        return result;
    if (size != 0) {
        (void)fwrite(data, 1, size, stderr);
        result = g_error("expected empty output: %s", path);
    }
    free(data);
    return result;
}
int g_equal(const char *left, const char *right) {
    unsigned char *a, *b;
    size_t na, nb;
    int result = g_read(left, &a, &na);
    if (result != 0)
        return result;
    result = g_read(right, &b, &nb);
    if (result == 0) {
        if (na != nb || memcmp(a, b, na) != 0)
            result = g_error("byte mismatch: expected %s; actual %s", left, right);
        free(b);
    }
    free(a);
    return result;
}
