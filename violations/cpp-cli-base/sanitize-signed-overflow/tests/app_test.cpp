#include <gtest/gtest.h>
#include <climits>

#include "test-cpp-project/app.hpp"

namespace test_cpp_project::test {

TEST(AppTest, GreetReturnsExpectedMessage) {
    auto result = greet();
    EXPECT_EQ(result, "Hello from test-cpp-project!");
}

TEST(AppTest, RunReturnsZero) {
    auto result = run();
    EXPECT_EQ(result, 0);
}

TEST(AppTest, OverflowTest) {
    int x = INT_MAX;
    int y = x + 1;
    EXPECT_NE(y, 0);
}

}  // namespace test_cpp_project::test
