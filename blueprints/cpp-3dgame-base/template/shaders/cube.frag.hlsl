// Cube fragment shader. Compiled at build time by DXC:
//   dxc -spirv -fspv-target-env=vulkan1.3 -T ps_6_0 -E main

struct PSInput {
    [[vk::location(0)]] float3 color : COLOR0;
};

float4 main(PSInput input) : SV_Target0 {
    return float4(input.color, 1.0);
}
