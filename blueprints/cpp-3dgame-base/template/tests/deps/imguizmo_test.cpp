#include <ImGuizmo.h>
#include <gtest/gtest.h>
#include <imgui.h>

namespace deps_test {

TEST(ImguizmoTest, ReportsIdleWithoutFrame) {
    ImGuiContext* context = ImGui::CreateContext();
    ASSERT_NE(context, nullptr);
    ImGuizmo::SetOrthographic(false);
    EXPECT_FALSE(ImGuizmo::IsUsing());
    ImGui::DestroyContext(context);
}

}  // namespace deps_test
