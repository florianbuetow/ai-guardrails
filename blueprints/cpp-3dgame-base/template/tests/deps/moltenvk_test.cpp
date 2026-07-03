#include <gtest/gtest.h>
#include <vulkan/vulkan.h>

namespace deps_test {

TEST(MoltenVKTest, ExportsVulkanEntryPoints) {
    uint32_t version = 0;
    ASSERT_EQ(vkEnumerateInstanceVersion(&version), VK_SUCCESS);
    EXPECT_GE(version, VK_API_VERSION_1_1);
}

}  // namespace deps_test
