#include <gtest/gtest.h>

// The Conan miniaudio package is header-only; exactly one TU provides the
// implementation.
#define MINIAUDIO_IMPLEMENTATION
#include <miniaudio.h>

#include <string>

namespace deps_test {

TEST(MiniaudioTest, ReportsVersion) {
    // No audio device is required for a version query.
    EXPECT_EQ(std::string{ma_version_string()}, std::string{MA_VERSION_STRING});
}

}  // namespace deps_test
