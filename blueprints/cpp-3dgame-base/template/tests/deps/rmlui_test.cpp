#include <RmlUi/Core.h>
#include <gtest/gtest.h>

#include <string>

namespace deps_test {

TEST(RmlUiTest, ReportsVersion) {
    // Full initialisation needs render/system interfaces; the version string
    // proves the library compiled and linked.
    EXPECT_FALSE(Rml::GetVersion().empty());
}

}  // namespace deps_test
