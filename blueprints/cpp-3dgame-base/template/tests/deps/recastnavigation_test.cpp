#include <gtest/gtest.h>
#include <recastnavigation/DetourNavMesh.h>
#include <recastnavigation/Recast.h>

namespace deps_test {

TEST(RecastNavigationTest, AllocatesCoreObjects) {
    rcHeightfield* heightfield = rcAllocHeightfield();
    ASSERT_NE(heightfield, nullptr);
    rcFreeHeightField(heightfield);

    dtNavMesh* nav_mesh = dtAllocNavMesh();
    ASSERT_NE(nav_mesh, nullptr);
    dtFreeNavMesh(nav_mesh);
}

}  // namespace deps_test
