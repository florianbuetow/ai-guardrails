#include <gtest/gtest.h>

// Compile the implementation with no linked Vulkan symbols; functions are
// supplied at allocator-creation time in real use.
#define VMA_STATIC_VULKAN_FUNCTIONS 0
#define VMA_DYNAMIC_VULKAN_FUNCTIONS 0
#define VMA_IMPLEMENTATION
#include <vk_mem_alloc.h>

namespace deps_test {

TEST(VmaTest, DeclaresAllocatorTypes) {
    VmaAllocatorCreateInfo create_info{};
    create_info.vulkanApiVersion = VK_API_VERSION_1_3;
    EXPECT_EQ(create_info.vulkanApiVersion, VK_API_VERSION_1_3);

    VmaAllocationCreateInfo alloc_info{};
    alloc_info.usage = VMA_MEMORY_USAGE_AUTO;
    EXPECT_EQ(alloc_info.usage, VMA_MEMORY_USAGE_AUTO);
}

}  // namespace deps_test
