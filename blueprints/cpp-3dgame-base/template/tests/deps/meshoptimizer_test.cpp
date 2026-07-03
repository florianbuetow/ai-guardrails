#include <gtest/gtest.h>
#include <meshoptimizer.h>

#include <array>
#include <cstdint>
#include <vector>

namespace deps_test {

TEST(MeshoptimizerTest, RemapsDuplicateVertices) {
    // Two triangles sharing an edge, with duplicated vertex data.
    const std::array<float, 18> vertices{
        0.0F,
        0.0F,
        0.0F,
        1.0F,
        0.0F,
        0.0F,
        0.0F,
        1.0F,
        0.0F,
        1.0F,
        0.0F,
        0.0F,
        1.0F,
        1.0F,
        0.0F,
        0.0F,
        1.0F,
        0.0F,
    };
    const std::size_t vertex_count = 6;
    std::vector<std::uint32_t> remap(vertex_count);
    const std::size_t unique = meshopt_generateVertexRemap(
        remap.data(), nullptr, vertex_count, vertices.data(), vertex_count, sizeof(float) * 3);
    EXPECT_EQ(unique, 4U);
}

}  // namespace deps_test
