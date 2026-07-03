#include <fmt/format.h>
#include <gtest/gtest.h>

namespace deps_test {

TEST(FmtTest, FormatsArguments) {
    EXPECT_EQ(fmt::format("{}-{}", "conan", 42), "conan-42");
}

}  // namespace deps_test
