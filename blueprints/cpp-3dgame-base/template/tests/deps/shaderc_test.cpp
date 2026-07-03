#include <gtest/gtest.h>

#include <cstdint>
#include <shaderc/shaderc.hpp>
#include <string>
#include <vector>

namespace deps_test {

TEST(ShadercTest, CompilesVertexShaderToSpirv) {
    const std::string source = "#version 450\nvoid main() { gl_Position = vec4(0.0); }\n";
    const shaderc::Compiler compiler;
    const shaderc::CompileOptions options;
    const shaderc::SpvCompilationResult result =
        compiler.CompileGlslToSpv(source, shaderc_glsl_vertex_shader, "smoke.vert", options);
    ASSERT_EQ(result.GetCompilationStatus(), shaderc_compilation_status_success) << result.GetErrorMessage();
    const std::vector<std::uint32_t> spirv{result.cbegin(), result.cend()};
    ASSERT_FALSE(spirv.empty());
    EXPECT_EQ(spirv.front(), 0x07230203U);  // SPIR-V magic number
}

}  // namespace deps_test
