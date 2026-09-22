#include "guard.h"
#include "sha256.h"

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    char hash[65];
    char *path;
    int seen;
} ManifestEntry;

static int hex_character(int character) {
    return (character >= '0' && character <= '9') || (character >= 'a' && character <= 'f');
}

static void free_entries(ManifestEntry *entries, size_t count) {
    size_t index;
    for (index = 0U; index < count; ++index)
        free(entries[index].path);
    free(entries);
}

static int parse_manifest(ManifestEntry **output, size_t *output_count) {
    unsigned char *data;
    size_t size, offset = 0U, count = 0U;
    ManifestEntry *entries = NULL;
    int result = g_read("vendor/mmixware/SHA256SUMS", &data, &size);
    if (result != 0)
        return result;
    if (size == 0U || data[size - 1U] != '\n' || memchr(data, 0, size) != NULL) {
        free(data);
        return g_internal("vendor manifest must be nonempty, NUL-free, and newline-terminated");
    }
    while (offset < size) {
        size_t start = offset, length, index;
        ManifestEntry *grown;
        char *path;
        while (offset < size && data[offset] != '\n')
            ++offset;
        length = offset - start;
        if (length > 0U && data[start + length - 1U] == '\r') {
            free(data);
            free_entries(entries, count);
            return g_internal("vendor/mmixware/SHA256SUMS: CRLF is forbidden");
        }
        if (length != 66U && length < 67U) {
            free(data);
            free_entries(entries, count);
            return g_internal("vendor/mmixware/SHA256SUMS: malformed line");
        }
        for (index = 0U; index < 64U; ++index)
            if (!hex_character(data[start + index])) {
                free(data);
                free_entries(entries, count);
                return g_internal("vendor/mmixware/SHA256SUMS: invalid SHA-256");
            }
        if (data[start + 64U] != ' ' || data[start + 65U] != ' ') {
            free(data);
            free_entries(entries, count);
            return g_internal("vendor/mmixware/SHA256SUMS: expected two spaces before path");
        }
        path = (char *)malloc(length - 65U);
        if (path == NULL) {
            free(data);
            free_entries(entries, count);
            return g_internal("out of memory");
        }
        (void)memcpy(path, data + start + 66U, length - 66U);
        path[length - 66U] = '\0';
        if (path[0] == '\0' || path[0] == '/' || strstr(path, "..") != NULL ||
            strchr(path, '\\') != NULL) {
            free(path);
            free(data);
            free_entries(entries, count);
            return g_internal("vendor/mmixware/SHA256SUMS: unsafe path");
        }
        for (index = 0U; index < count; ++index)
            if (strcmp(entries[index].path, path) == 0) {
                free(path);
                free(data);
                free_entries(entries, count);
                return g_internal("vendor/mmixware/SHA256SUMS: duplicate path");
            }
        grown = (ManifestEntry *)realloc(entries, (count + 1U) * sizeof(*entries));
        if (grown == NULL) {
            free(path);
            free(data);
            free_entries(entries, count);
            return g_internal("out of memory");
        }
        entries = grown;
        (void)memcpy(entries[count].hash, data + start, 64U);
        entries[count].hash[64U] = '\0';
        entries[count].path = path;
        entries[count].seen = 0;
        ++count;
        if (offset < size)
            ++offset;
    }
    free(data);
    if (count == 0U) {
        free_entries(entries, count);
        return g_internal("vendor/mmixware/SHA256SUMS: empty manifest");
    }
    *output = entries;
    *output_count = count;
    return 0;
}

static int digest_file(const char *path, char output[65]) {
    unsigned char *data, digest[32];
    size_t size, index;
    GSha256 context;
    int result = g_read(path, &data, &size);
    static const char digits[] = "0123456789abcdef";
    if (result != 0)
        return result;
    g_sha256_init(&context);
    g_sha256_update(&context, data, size);
    g_sha256_finish(&context, digest);
    free(data);
    for (index = 0U; index < 32U; ++index) {
        output[index * 2U] = digits[digest[index] >> 4U];
        output[index * 2U + 1U] = digits[digest[index] & 15U];
    }
    output[64] = '\0';
    return 0;
}

static const char *relative_vendor_path(const char *path) {
    static const char prefix[] = "vendor/mmixware/";
    const char *position = strstr(path, prefix);
    return position == NULL ? NULL : position + sizeof(prefix) - 1U;
}

int g_vendor(void) {
    ManifestEntry *entries = NULL;
    size_t count = 0U, index, other;
    GPaths files = {0};
    int errors = 0, result = parse_manifest(&entries, &count);
    if (result != 0)
        return result;
    result = g_list("vendor/mmixware", &files);
    if (result != 0) {
        free_entries(entries, count);
        return result;
    }
    for (index = 0U; index < files.count; ++index) {
        const char *relative = relative_vendor_path(files.items[index]);
        char actual[65];
        int found = 0;
        if (relative == NULL) {
            errors++;
            (void)g_error("vendor listing returned path outside vendor/mmixware: %s",
                          files.items[index]);
            continue;
        }
        if (strcmp(relative, "SHA256SUMS") == 0)
            continue;
        for (other = 0U; other < count; ++other)
            if (strcmp(entries[other].path, relative) == 0) {
                found = 1;
                entries[other].seen = 1;
                result = digest_file(files.items[index], actual);
                if (result == 2) {
                    errors = 2;
                    goto done;
                }
                if (result != 0) {
                    ++errors;
                    break;
                }
                if (strcmp(actual, entries[other].hash) != 0) {
                    ++errors;
                    (void)g_error("vendor integrity mismatch: %s", relative);
                }
                break;
            }
        if (!found) {
            ++errors;
            (void)g_error("unexpected protected vendor file: %s", relative);
        }
    }
    for (index = 0U; index < count; ++index)
        if (!entries[index].seen) {
            ++errors;
            (void)g_error("missing protected vendor file: %s", entries[index].path);
        }
done:
    g_paths_free(&files);
    free_entries(entries, count);
    return errors == 0 ? 0 : (errors == 2 ? 2 : 1);
}
