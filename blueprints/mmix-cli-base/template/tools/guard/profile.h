#ifndef MMIX_GUARD_PROFILE_H
#define MMIX_GUARD_PROFILE_H

int g_listing(const char *path);
int g_object(const char *path);
int g_coverage(const char *listing, const char *profile);
int g_coverage_all(void);
int g_profile_selftest(void);

#endif
