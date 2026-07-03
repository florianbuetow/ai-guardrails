#include <gtest/gtest.h>

#include <cstdint>
#include <spirv-tools/libspirv.hpp>
#include <string>
#include <vector>

namespace deps_test {

TEST(SpirvToolsTest, AssemblesAndValidatesModule) {
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
    EXPECT_TRUE(tools.Validate(binary));
}

}  // namespace deps_test
