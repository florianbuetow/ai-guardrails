#include <gtest/gtest.h>
#include <imgui.h>

#include <string>

namespace deps_test {

TEST(ImguiTest, CreatesContext) {
    IMGUI_CHECKVERSION();
    ImGuiContext* context = ImGui::CreateContext();
    ASSERT_NE(context, nullptr);
    EXPECT_FALSE(std::string{ImGui::GetVersion()}.empty());
    ImGui::DestroyContext(context);
}

}  // namespace deps_test
