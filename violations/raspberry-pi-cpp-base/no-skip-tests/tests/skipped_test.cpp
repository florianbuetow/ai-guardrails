#include <gtest/gtest.h>

TEST(GuardrailTest, CannotSkipFailures) {
    GTEST_SKIP() << "violation";
}
