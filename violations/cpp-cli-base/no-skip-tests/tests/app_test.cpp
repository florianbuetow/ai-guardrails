#include <gtest/gtest.h>

#include "test-cpp-project/app.hpp"

namespace test_cpp_project::test {

TEST(AppTest, GreetReturnsExpectedMessage) {
    auto result = greet();
    EXPECT_EQ(result, "Hello from test-cpp-project!");
}

TEST(AppTest, DISABLED_RunReturnsZero) {
    auto result = run();
    EXPECT_EQ(result, 0);
}

}  // namespace test_cpp_project::test
