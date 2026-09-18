#include <gtest/gtest.h>

#include "test-cpp-3dgame-project/app.hpp"

namespace test_cpp_3dgame_project::test {

TEST(AppTest, GreetReturnsExpectedMessage) {
    auto result = greet();
    EXPECT_EQ(result, "Hello from test-cpp-3dgame-project!");
}

TEST(AppTest, DISABLED_RunReturnsZero) {
    auto result = run();
    EXPECT_EQ(result, 0);
}

}  // namespace test_cpp_3dgame_project::test
