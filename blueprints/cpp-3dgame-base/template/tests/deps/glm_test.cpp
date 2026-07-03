#include <gtest/gtest.h>

#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>

namespace deps_test {

TEST(GlmTest, TransformsVector) {
    const glm::vec4 point{1.0F, 0.0F, 0.0F, 1.0F};
    const glm::mat4 translate = glm::translate(glm::mat4{1.0F}, glm::vec3{0.0F, 2.0F, 0.0F});
    const glm::vec4 moved = translate * point;
    EXPECT_FLOAT_EQ(moved.x, 1.0F);
    EXPECT_FLOAT_EQ(moved.y, 2.0F);
}

}  // namespace deps_test
