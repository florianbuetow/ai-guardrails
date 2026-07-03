#include <gtest/gtest.h>
#include <vulkan/vulkan_core.h>

namespace deps_test {

TEST(VulkanHeadersTest, ProvidesApiConstants) {
    VkApplicationInfo info{};
    info.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
    info.apiVersion = VK_API_VERSION_1_3;
    EXPECT_EQ(info.sType, VK_STRUCTURE_TYPE_APPLICATION_INFO);
    EXPECT_GE(VK_HEADER_VERSION, 313);
}

}  // namespace deps_test
