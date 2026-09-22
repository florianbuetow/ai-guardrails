#ifndef MMIX_GUARD_SOURCE_H
#define MMIX_GUARD_SOURCE_H

#include <stddef.h>

typedef struct {
    char **items;
    size_t count;
} SourceSet;

void source_set_free(SourceSet *set);

#endif
