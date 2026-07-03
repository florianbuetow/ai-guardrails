#include <gtest/gtest.h>

#include <entt/entt.hpp>

namespace deps_test {

struct Position {
    float x{};
    float y{};
};

TEST(EnttTest, CreatesEntityWithComponent) {
    entt::registry registry;
    const entt::entity entity = registry.create();
    registry.emplace<Position>(entity, 1.0F, 2.0F);
    const auto& pos = registry.get<Position>(entity);
    EXPECT_FLOAT_EQ(pos.x, 1.0F);
    EXPECT_FLOAT_EQ(pos.y, 2.0F);
}

}  // namespace deps_test
