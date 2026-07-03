#include <cstdint>
#include <gtest/gtest.h>
#include <spirv-tools/libspirv.hpp>
#include <spirv_glsl.hpp>
#include <string>
#include <vector>

namespace deps_test {

TEST(SpirvCrossTest, DecompilesSpirvToGlsl) {
    // Assemble a minimal valid module with SPIRV-Tools, then decompile it
    // with SPIRV-Cross — the same SPIR-V-only flow the engine uses (shaders
    // themselves are compiled from HLSL by DXC at build time).
    const std::string assembly = R"(OpCapability Shader
OpMemoryModel Logical GLSL450
OpEntryPoint GLCompute %main "main"
OpExecutionMode %main LocalSize 1 1 1
%void = OpTypeVoid
%fn = OpTypeFunction %void
%main = OpFunction %void None %fn
%entry = OpLabel
OpReturn
OpFunctionEnd
)";
    spvtools::SpirvTools tools(SPV_ENV_VULKAN_1_3);
    ASSERT_TRUE(tools.IsValid());
    std::vector<std::uint32_t> binary;
    ASSERT_TRUE(tools.Assemble(assembly, &binary));

    spirv_cross::CompilerGLSL cross{std::move(binary)};
    const std::string decompiled = cross.compile();
    EXPECT_NE(decompiled.find("void main"), std::string::npos);
}

}  // namespace deps_test
