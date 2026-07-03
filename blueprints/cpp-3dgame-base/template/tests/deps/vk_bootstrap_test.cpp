#include <VkBootstrap.h>
#include <gtest/gtest.h>

namespace deps_test {

TEST(VkBootstrapTest, QueriesSystemInfo) {
    const auto info = vkb::SystemInfo::get_system_info();
    if (info.has_value()) {
        // A Vulkan loader is present; enumeration succeeded.
        SUCCEED();
    } else {
        // No Vulkan runtime in the default search path: the call must fail
        // through vk-bootstrap's error machinery with a readable message.
        EXPECT_FALSE(info.error().message().empty());
    }
}

}  // namespace deps_test
