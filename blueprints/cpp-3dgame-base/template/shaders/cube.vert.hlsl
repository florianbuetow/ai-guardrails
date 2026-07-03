// Cube vertex shader. Compiled at build time by DXC:
//   dxc -spirv -fspv-target-env=vulkan1.3 -T vs_6_0 -E main -Zpc
// -Zpc packs matrices column-major so the GLM mat4 push constant is
// consumed without a transpose.

struct PushConstants {
    float4x4 mvp;
};

[[vk::push_constant]] PushConstants push;

struct VSInput {
    [[vk::location(0)]] float3 position : POSITION0;
    [[vk::location(1)]] float3 color : COLOR0;
};

struct VSOutput {
    float4 position : SV_Position;
    [[vk::location(0)]] float3 color : COLOR0;
};

VSOutput main(VSInput input) {
    VSOutput output;
    output.position = mul(push.mvp, float4(input.position, 1.0));
    output.color = input.color;
    return output;
}
