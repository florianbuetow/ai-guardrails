#include <gtest/gtest.h>
#include <ozz/animation/runtime/skeleton.h>

namespace deps_test {

TEST(OzzAnimationTest, ConstructsEmptySkeleton) {
    const ozz::animation::Skeleton skeleton;
    EXPECT_EQ(skeleton.num_joints(), 0);
}

}  // namespace deps_test
