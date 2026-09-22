#ifndef MMIX_GUARD_SHA256_H
#define MMIX_GUARD_SHA256_H

#include <stddef.h>
#include <stdint.h>

typedef struct {
    uint32_t state[8];
    uint64_t bit_count;
    unsigned char block[64];
    size_t block_size;
} GSha256;

void g_sha256_init(GSha256 *context);
void g_sha256_update(GSha256 *context, const unsigned char *data, size_t size);
void g_sha256_finish(GSha256 *context, unsigned char digest[32]);
int g_sha256_selftest(void);

#endif
