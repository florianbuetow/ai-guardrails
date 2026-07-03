#include <gtest/gtest.h>

#include <cstdint>
#include <shaderc/shaderc.hpp>
#include <spirv_glsl.hpp>
#include <string>
#include <vector>

namespace deps_test {

TEST(SpirvCrossTest, DecompilesSpirvToGlsl) {
    const std::string source = "#version 450\nvoid main() { gl_Position = vec4(0.0); }\n";
    const shaderc::Compiler compiler;
    const shaderc::CompileOptions options;
    const shaderc::SpvCompilationResult result =
        compiler.CompileGlslToSpv(source, shaderc_glsl_vertex_shader, "smoke.vert", options);
    ASSERT_EQ(result.GetCompilationStatus(), shaderc_compilation_status_success) << result.GetErrorMessage();

    spirv_cross::CompilerGLSL cross{std::vector<std::uint32_t>{result.cbegin(), result.cend()}};
    const std::string glsl = cross.compile();
    EXPECT_NE(glsl.find("void main"), std::string::npos);
}

}  // namespace deps_test
