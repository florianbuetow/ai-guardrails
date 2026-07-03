#include <gtest/gtest.h>
#include <volk.h>

namespace deps_test {

TEST(VolkTest, InitializesOrReportsMissingLoader) {
    EXPECT_EQ(volkGetInstanceVersion(), 0U);
    const VkResult result = volkInitialize();
    if (result == VK_SUCCESS) {
        EXPECT_GT(volkGetInstanceVersion(), 0U);
        volkFinalize();
    } else {
        // No Vulkan runtime on this machine: the library itself still linked
        // and executed, which is what this smoke test demonstrates.
        EXPECT_EQ(result, VK_ERROR_INITIALIZATION_FAILED);
    }
}

}  // namespace deps_test
