#ifndef MMIX_GUARD_H
#define MMIX_GUARD_H
#include <stddef.h>
#include <stdint.h>
#ifdef _WIN32
#define G_EXE ".exe"
#else
#define G_EXE ""
#endif
#define G_ASSEMBLER "build/bin/mmixal" G_EXE
#define G_SIMULATOR "build/bin/mmix" G_EXE
#define G_OBJECT_TOOL "build/bin/mmotype" G_EXE

typedef struct {
    char **items;
    size_t count;
} GPaths;
typedef struct {
    char **keys;
    char **values;
    size_t count;
} GConfig;
void g_diagnostic(const char *format, ...);
/* Diagnostics never determine status: validation is 1, internal/configuration errors are 2. */
#define g_error(...) (g_diagnostic(__VA_ARGS__), 1)
#define g_internal(...) (g_diagnostic(__VA_ARGS__), 2)
int g_read(const char *path, unsigned char **data, size_t *size);
int g_write(const char *path, const void *data, size_t size);
int g_mkdir(const char *path);
int g_list(const char *directory, GPaths *paths);
void g_paths_free(GPaths *paths);
int g_config_load(const char *path, GConfig *config);
const char *g_config_get(const GConfig *config, const char *key);
void g_config_free(GConfig *config);
int g_u64(const char *text, unsigned base, uint64_t *value);
int g_run(const char *const argv[], const char *input, const char *output, const char *errors,
          int *status, unsigned timeout_seconds);
int g_empty(const char *path);
int g_equal(const char *left, const char *right);
int g_assemble(const char *entry, const char *stem, int production);
int g_build_tools(void);
char *g_compiler(void);
int g_source(int count, const char *const paths[]);
int g_vendor(void);
int g_hygiene(int count, const char *const paths[]);
int g_listing(const char *path);
int g_object(const char *path);
int g_test(const char *path);
int g_test_all(const char *directory);
int g_coverage(const char *listing, const char *profile);
int g_coverage_all(void);
int g_selftest(void);
int g_source_selftest(void);
int g_test_selftest(void);
int g_profile_selftest(void);
#endif
