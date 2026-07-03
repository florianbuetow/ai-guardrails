#include <array>
#include <gtest/gtest.h>
#include <mikktspace.h>

namespace deps_test {

namespace {

constexpr std::array<std::array<float, 3>, 3> kPositions{{{0.0F, 0.0F, 0.0F}, {1.0F, 0.0F, 0.0F}, {0.0F, 1.0F, 0.0F}}};
constexpr std::array<std::array<float, 2>, 3> kTexCoords{{{0.0F, 0.0F}, {1.0F, 0.0F}, {0.0F, 1.0F}}};

int g_tangent_count = 0;

int GetNumFaces(const SMikkTSpaceContext* /*context*/) {
    return 1;
}

int GetNumVerticesOfFace(const SMikkTSpaceContext* /*context*/, int /*face*/) {
    return 3;
}

void GetPosition(const SMikkTSpaceContext* /*context*/, float out[], int /*face*/, int vert) {
    const auto& pos = kPositions.at(static_cast<std::size_t>(vert));
    out[0] = pos[0];
    out[1] = pos[1];
    out[2] = pos[2];
}

void GetNormal(const SMikkTSpaceContext* /*context*/, float out[], int /*face*/, int /*vert*/) {
    out[0] = 0.0F;
    out[1] = 0.0F;
    out[2] = 1.0F;
}

void GetTexCoord(const SMikkTSpaceContext* /*context*/, float out[], int /*face*/, int vert) {
    const auto& uv = kTexCoords.at(static_cast<std::size_t>(vert));
    out[0] = uv[0];
    out[1] = uv[1];
}

void SetTSpaceBasic(
    const SMikkTSpaceContext* /*context*/, const float /*tangent*/[], float /*sign*/, int /*face*/, int /*vert*/) {
    ++g_tangent_count;
}

}  // namespace

TEST(MikktspaceTest, GeneratesTangentsForTriangle) {
    SMikkTSpaceInterface iface{};
    iface.m_getNumFaces = GetNumFaces;
    iface.m_getNumVerticesOfFace = GetNumVerticesOfFace;
    iface.m_getPosition = GetPosition;
    iface.m_getNormal = GetNormal;
    iface.m_getTexCoord = GetTexCoord;
    iface.m_setTSpaceBasic = SetTSpaceBasic;

    SMikkTSpaceContext context{};
    context.m_pInterface = &iface;

    g_tangent_count = 0;
    EXPECT_NE(genTangSpaceDefault(&context), 0);
    EXPECT_EQ(g_tangent_count, 3);
}

}  // namespace deps_test
