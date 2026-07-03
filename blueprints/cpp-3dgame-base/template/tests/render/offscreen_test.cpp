// Headless GPU rendering test: renders one frame of the cube to an offscreen
// image (no window, no surface, no swapchain) and reads the pixels back.
// Proves the whole GPU pipeline — instance, device, DXC-compiled HLSL
// shaders, rasterization — actually renders, in CI, without a display.
//
// Requires a Vulkan implementation (MoltenVK on macOS, lavapipe/Mesa on
// headless Linux). Run via `just test-render`, which provides the shader
// directory through the SHADER_DIR environment variable; this binary is
// deliberately not registered with ctest.

#include <VkBootstrap.h>
#include <array>
#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <filesystem>
#include <format>
#include <fstream>
#include <glm/ext/matrix_clip_space.hpp>
#include <glm/ext/matrix_float4x4.hpp>
#include <glm/ext/matrix_transform.hpp>
#include <glm/ext/vector_float3.hpp>
#include <glm/trigonometric.hpp>
#include <gtest/gtest.h>
#include <ios>
#include <stdexcept>
#include <string>
#include <vector>
#include <vulkan/vulkan_core.h>

namespace render_test {
namespace {

constexpr std::uint32_t image_size = 64;

struct Vertex {
    std::array<float, 3> position;
    std::array<float, 3> color;
};

// A single bright red quad (two triangles) facing the camera.
constexpr std::array<Vertex, 6> quad_vertices{{
    {.position = {-0.5F, -0.5F, 0.0F}, .color = {0.9F, 0.1F, 0.1F}},
    {.position = {0.5F, -0.5F, 0.0F}, .color = {0.9F, 0.1F, 0.1F}},
    {.position = {0.5F, 0.5F, 0.0F}, .color = {0.9F, 0.1F, 0.1F}},
    {.position = {-0.5F, -0.5F, 0.0F}, .color = {0.9F, 0.1F, 0.1F}},
    {.position = {0.5F, 0.5F, 0.0F}, .color = {0.9F, 0.1F, 0.1F}},
    {.position = {-0.5F, 0.5F, 0.0F}, .color = {0.9F, 0.1F, 0.1F}},
}};

void vk_check(VkResult result, const std::string& what) {
    if (result != VK_SUCCESS) {
        throw std::runtime_error(std::format("{} failed (VkResult {})", what, static_cast<int>(result)));
    }
}

std::vector<std::uint32_t> load_spirv_file(const std::filesystem::path& path) {
    std::ifstream file{path, std::ios::binary | std::ios::ate};
    if (!file) {
        throw std::runtime_error(std::format("cannot open {}", path.string()));
    }
    const std::streamsize byte_count = file.tellg();
    if (byte_count <= 0 || byte_count % 4 != 0) {
        throw std::runtime_error(std::format("{} is not a SPIR-V module", path.string()));
    }
    std::vector<char> bytes(static_cast<std::size_t>(byte_count));
    file.seekg(0);
    if (!file.read(bytes.data(), byte_count)) {
        throw std::runtime_error(std::format("cannot read {}", path.string()));
    }
    std::vector<std::uint32_t> words(bytes.size() / 4);
    for (std::size_t idx = 0; idx < words.size(); ++idx) {
        const std::size_t base = idx * 4;
        const auto byte_at = [&bytes](std::size_t offset) {
            return static_cast<std::uint32_t>(static_cast<unsigned char>(bytes.at(offset)));
        };
        words.at(idx) =
            byte_at(base) | (byte_at(base + 1) << 8U) | (byte_at(base + 2) << 16U) | (byte_at(base + 3) << 24U);
    }
    return words;
}

std::filesystem::path shader_dir_from_env() {
    const char* dir = std::getenv("SHADER_DIR");
    if (dir == nullptr || *dir == '\0') {
        throw std::runtime_error("SHADER_DIR is not set; run via `just test-render`");
    }
    return std::filesystem::path{dir};
}

std::uint32_t find_memory_type(VkPhysicalDevice physical_device,
                               std::uint32_t type_bits,
                               VkMemoryPropertyFlags properties) {
    VkPhysicalDeviceMemoryProperties memory_properties{};
    vkGetPhysicalDeviceMemoryProperties(physical_device, &memory_properties);
    for (std::uint32_t idx = 0; idx < memory_properties.memoryTypeCount; ++idx) {
        const bool type_allowed = (type_bits & (1U << idx)) != 0;
        const bool props_present = (memory_properties.memoryTypes[idx].propertyFlags & properties) == properties;
        if (type_allowed && props_present) {
            return idx;
        }
    }
    throw std::runtime_error("no suitable Vulkan memory type found");
}

}  // namespace

TEST(OffscreenRenderTest, RendersQuadToReadbackBuffer) {
    // --- Instance + device (no surface, no swapchain) ---
    auto instance_result = vkb::InstanceBuilder{}
                               .set_app_name("offscreen render test")
                               .require_api_version(1, 3, 0)
                               .set_headless(true)
                               .build();
    ASSERT_TRUE(instance_result) << instance_result.error().message();
    vkb::Instance instance = instance_result.value();

    VkPhysicalDeviceVulkan13Features features13{};
    features13.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_3_FEATURES;
    features13.dynamicRendering = VK_TRUE;
    features13.synchronization2 = VK_TRUE;

    auto physical_result = vkb::PhysicalDeviceSelector{instance}
                               .set_minimum_version(1, 3)
                               .set_required_features_13(features13)
                               .defer_surface_initialization()
                               .select();
    ASSERT_TRUE(physical_result) << physical_result.error().message();

    auto device_result = vkb::DeviceBuilder{physical_result.value()}.build();
    ASSERT_TRUE(device_result) << device_result.error().message();
    vkb::Device device = device_result.value();
    VkDevice dev = device.device;
    VkPhysicalDevice phys = physical_result.value().physical_device;

    auto queue_result = device.get_queue(vkb::QueueType::graphics);
    auto queue_family_result = device.get_queue_index(vkb::QueueType::graphics);
    ASSERT_TRUE(queue_result);
    ASSERT_TRUE(queue_family_result);
    VkQueue queue = queue_result.value();

    // --- Offscreen color image ---
    VkImageCreateInfo image_info{};
    image_info.sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
    image_info.imageType = VK_IMAGE_TYPE_2D;
    image_info.format = VK_FORMAT_R8G8B8A8_UNORM;
    image_info.extent = VkExtent3D{.width = image_size, .height = image_size, .depth = 1};
    image_info.mipLevels = 1;
    image_info.arrayLayers = 1;
    image_info.samples = VK_SAMPLE_COUNT_1_BIT;
    image_info.tiling = VK_IMAGE_TILING_OPTIMAL;
    image_info.usage = static_cast<VkImageUsageFlags>(VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT) |
                       static_cast<VkImageUsageFlags>(VK_IMAGE_USAGE_TRANSFER_SRC_BIT);
    image_info.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
    VkImage image = VK_NULL_HANDLE;
    vk_check(vkCreateImage(dev, &image_info, nullptr, &image), "vkCreateImage");

    VkMemoryRequirements image_requirements{};
    vkGetImageMemoryRequirements(dev, image, &image_requirements);
    VkMemoryAllocateInfo image_alloc{};
    image_alloc.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
    image_alloc.allocationSize = image_requirements.size;
    image_alloc.memoryTypeIndex =
        find_memory_type(phys, image_requirements.memoryTypeBits, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
    VkDeviceMemory image_memory = VK_NULL_HANDLE;
    vk_check(vkAllocateMemory(dev, &image_alloc, nullptr, &image_memory), "vkAllocateMemory(image)");
    vk_check(vkBindImageMemory(dev, image, image_memory, 0), "vkBindImageMemory");

    VkImageViewCreateInfo view_info{};
    view_info.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
    view_info.image = image;
    view_info.viewType = VK_IMAGE_VIEW_TYPE_2D;
    view_info.format = VK_FORMAT_R8G8B8A8_UNORM;
    view_info.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    view_info.subresourceRange.levelCount = 1;
    view_info.subresourceRange.layerCount = 1;
    VkImageView image_view = VK_NULL_HANDLE;
    vk_check(vkCreateImageView(dev, &view_info, nullptr, &image_view), "vkCreateImageView");

    // --- Host-visible buffers: vertex data in, pixels out ---
    const auto make_buffer =
        [&](VkDeviceSize size, VkBufferUsageFlags usage, VkBuffer& buffer, VkDeviceMemory& memory) {
            VkBufferCreateInfo buffer_info{};
            buffer_info.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
            buffer_info.size = size;
            buffer_info.usage = usage;
            buffer_info.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
            vk_check(vkCreateBuffer(dev, &buffer_info, nullptr, &buffer), "vkCreateBuffer");
            VkMemoryRequirements requirements{};
            vkGetBufferMemoryRequirements(dev, buffer, &requirements);
            VkMemoryAllocateInfo alloc_info{};
            alloc_info.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
            alloc_info.allocationSize = requirements.size;
            alloc_info.memoryTypeIndex =
                find_memory_type(phys,
                                 requirements.memoryTypeBits,
                                 static_cast<VkMemoryPropertyFlags>(VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT) |
                                     static_cast<VkMemoryPropertyFlags>(VK_MEMORY_PROPERTY_HOST_COHERENT_BIT));
            vk_check(vkAllocateMemory(dev, &alloc_info, nullptr, &memory), "vkAllocateMemory(buffer)");
            vk_check(vkBindBufferMemory(dev, buffer, memory, 0), "vkBindBufferMemory");
        };

    VkBuffer vertex_buffer = VK_NULL_HANDLE;
    VkDeviceMemory vertex_memory = VK_NULL_HANDLE;
    make_buffer(sizeof(quad_vertices), VK_BUFFER_USAGE_VERTEX_BUFFER_BIT, vertex_buffer, vertex_memory);
    {
        void* mapped = nullptr;
        vk_check(vkMapMemory(dev, vertex_memory, 0, sizeof(quad_vertices), 0, &mapped), "vkMapMemory");
        auto* vertices = static_cast<Vertex*>(mapped);
        for (std::size_t idx = 0; idx < quad_vertices.size(); ++idx) {
            *std::next(vertices, static_cast<std::ptrdiff_t>(idx)) = quad_vertices.at(idx);
        }
        vkUnmapMemory(dev, vertex_memory);
    }

    constexpr VkDeviceSize readback_size = static_cast<VkDeviceSize>(image_size) * image_size * 4;
    VkBuffer readback_buffer = VK_NULL_HANDLE;
    VkDeviceMemory readback_memory = VK_NULL_HANDLE;
    make_buffer(readback_size, VK_BUFFER_USAGE_TRANSFER_DST_BIT, readback_buffer, readback_memory);

    // --- Pipeline from the DXC-compiled HLSL shaders ---
    const std::filesystem::path shader_dir = shader_dir_from_env();
    const std::vector<std::uint32_t> vertex_spirv = load_spirv_file(shader_dir / "cube.vert.spv");
    const std::vector<std::uint32_t> fragment_spirv = load_spirv_file(shader_dir / "cube.frag.spv");

    const auto make_module = [&](const std::vector<std::uint32_t>& spirv) {
        VkShaderModuleCreateInfo module_info{};
        module_info.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
        module_info.codeSize = spirv.size() * sizeof(std::uint32_t);
        module_info.pCode = spirv.data();
        VkShaderModule shader_module = VK_NULL_HANDLE;
        vk_check(vkCreateShaderModule(dev, &module_info, nullptr, &shader_module), "vkCreateShaderModule");
        return shader_module;
    };
    VkShaderModule vertex_module = make_module(vertex_spirv);
    VkShaderModule fragment_module = make_module(fragment_spirv);

    VkPushConstantRange push_range{};
    push_range.stageFlags = VK_SHADER_STAGE_VERTEX_BIT;
    push_range.size = sizeof(glm::mat4);
    VkPipelineLayoutCreateInfo layout_info{};
    layout_info.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
    layout_info.pushConstantRangeCount = 1;
    layout_info.pPushConstantRanges = &push_range;
    VkPipelineLayout pipeline_layout = VK_NULL_HANDLE;
    vk_check(vkCreatePipelineLayout(dev, &layout_info, nullptr, &pipeline_layout), "vkCreatePipelineLayout");

    const std::array<VkPipelineShaderStageCreateInfo, 2> stages{{
        VkPipelineShaderStageCreateInfo{
            .sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            .pNext = nullptr,
            .flags = 0,
            .stage = VK_SHADER_STAGE_VERTEX_BIT,
            .module = vertex_module,
            .pName = "main",
            .pSpecializationInfo = nullptr,
        },
        VkPipelineShaderStageCreateInfo{
            .sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            .pNext = nullptr,
            .flags = 0,
            .stage = VK_SHADER_STAGE_FRAGMENT_BIT,
            .module = fragment_module,
            .pName = "main",
            .pSpecializationInfo = nullptr,
        },
    }};

    VkVertexInputBindingDescription binding{};
    binding.stride = sizeof(Vertex);
    binding.inputRate = VK_VERTEX_INPUT_RATE_VERTEX;
    const std::array<VkVertexInputAttributeDescription, 2> attributes{{
        VkVertexInputAttributeDescription{
            .location = 0, .binding = 0, .format = VK_FORMAT_R32G32B32_SFLOAT, .offset = 0},
        VkVertexInputAttributeDescription{
            .location = 1, .binding = 0, .format = VK_FORMAT_R32G32B32_SFLOAT, .offset = offsetof(Vertex, color)},
    }};
    VkPipelineVertexInputStateCreateInfo vertex_input{};
    vertex_input.sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;
    vertex_input.vertexBindingDescriptionCount = 1;
    vertex_input.pVertexBindingDescriptions = &binding;
    vertex_input.vertexAttributeDescriptionCount = static_cast<std::uint32_t>(attributes.size());
    vertex_input.pVertexAttributeDescriptions = attributes.data();

    VkPipelineInputAssemblyStateCreateInfo input_assembly{};
    input_assembly.sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
    input_assembly.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;

    const VkViewport viewport{.x = 0.0F,
                              .y = 0.0F,
                              .width = static_cast<float>(image_size),
                              .height = static_cast<float>(image_size),
                              .minDepth = 0.0F,
                              .maxDepth = 1.0F};
    const VkRect2D scissor{.offset = {.x = 0, .y = 0}, .extent = {.width = image_size, .height = image_size}};
    VkPipelineViewportStateCreateInfo viewport_state{};
    viewport_state.sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
    viewport_state.viewportCount = 1;
    viewport_state.pViewports = &viewport;
    viewport_state.scissorCount = 1;
    viewport_state.pScissors = &scissor;

    VkPipelineRasterizationStateCreateInfo rasterization{};
    rasterization.sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
    rasterization.polygonMode = VK_POLYGON_MODE_FILL;
    rasterization.cullMode = VK_CULL_MODE_NONE;
    rasterization.frontFace = VK_FRONT_FACE_COUNTER_CLOCKWISE;
    rasterization.lineWidth = 1.0F;

    const VkPipelineMultisampleStateCreateInfo multisample{
        .sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        .pNext = nullptr,
        .flags = 0,
        .rasterizationSamples = VK_SAMPLE_COUNT_1_BIT,
        .sampleShadingEnable = VK_FALSE,
        .minSampleShading = 0.0F,
        .pSampleMask = nullptr,
        .alphaToCoverageEnable = VK_FALSE,
        .alphaToOneEnable = VK_FALSE,
    };

    VkPipelineColorBlendAttachmentState blend_attachment{};
    blend_attachment.colorWriteMask = static_cast<VkColorComponentFlags>(VK_COLOR_COMPONENT_R_BIT) |
                                      static_cast<VkColorComponentFlags>(VK_COLOR_COMPONENT_G_BIT) |
                                      static_cast<VkColorComponentFlags>(VK_COLOR_COMPONENT_B_BIT) |
                                      static_cast<VkColorComponentFlags>(VK_COLOR_COMPONENT_A_BIT);
    VkPipelineColorBlendStateCreateInfo color_blend{};
    color_blend.sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
    color_blend.attachmentCount = 1;
    color_blend.pAttachments = &blend_attachment;

    VkFormat color_format = VK_FORMAT_R8G8B8A8_UNORM;
    VkPipelineRenderingCreateInfo rendering_info{};
    rendering_info.sType = VK_STRUCTURE_TYPE_PIPELINE_RENDERING_CREATE_INFO;
    rendering_info.colorAttachmentCount = 1;
    rendering_info.pColorAttachmentFormats = &color_format;

    VkGraphicsPipelineCreateInfo pipeline_info{};
    pipeline_info.sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
    pipeline_info.pNext = &rendering_info;
    pipeline_info.stageCount = static_cast<std::uint32_t>(stages.size());
    pipeline_info.pStages = stages.data();
    pipeline_info.pVertexInputState = &vertex_input;
    pipeline_info.pInputAssemblyState = &input_assembly;
    pipeline_info.pViewportState = &viewport_state;
    pipeline_info.pRasterizationState = &rasterization;
    pipeline_info.pMultisampleState = &multisample;
    pipeline_info.pColorBlendState = &color_blend;
    pipeline_info.layout = pipeline_layout;
    VkPipeline pipeline = VK_NULL_HANDLE;
    vk_check(vkCreateGraphicsPipelines(dev, VK_NULL_HANDLE, 1, &pipeline_info, nullptr, &pipeline),
             "vkCreateGraphicsPipelines");

    // --- Record: clear, draw, copy out ---
    VkCommandPoolCreateInfo pool_info{};
    pool_info.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
    pool_info.queueFamilyIndex = queue_family_result.value();
    VkCommandPool command_pool = VK_NULL_HANDLE;
    vk_check(vkCreateCommandPool(dev, &pool_info, nullptr, &command_pool), "vkCreateCommandPool");

    VkCommandBufferAllocateInfo cmd_alloc{};
    cmd_alloc.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
    cmd_alloc.commandPool = command_pool;
    cmd_alloc.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    cmd_alloc.commandBufferCount = 1;
    VkCommandBuffer cmd = VK_NULL_HANDLE;
    vk_check(vkAllocateCommandBuffers(dev, &cmd_alloc, &cmd), "vkAllocateCommandBuffers");

    VkCommandBufferBeginInfo begin_info{};
    begin_info.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
    begin_info.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
    vk_check(vkBeginCommandBuffer(cmd, &begin_info), "vkBeginCommandBuffer");

    VkImageMemoryBarrier2 to_color{};
    to_color.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER_2;
    to_color.srcStageMask = VK_PIPELINE_STAGE_2_TOP_OF_PIPE_BIT;
    to_color.dstStageMask = VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT;
    to_color.dstAccessMask = VK_ACCESS_2_COLOR_ATTACHMENT_WRITE_BIT;
    to_color.oldLayout = VK_IMAGE_LAYOUT_UNDEFINED;
    to_color.newLayout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
    to_color.image = image;
    to_color.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    to_color.subresourceRange.levelCount = 1;
    to_color.subresourceRange.layerCount = 1;
    VkDependencyInfo dependency_in{};
    dependency_in.sType = VK_STRUCTURE_TYPE_DEPENDENCY_INFO;
    dependency_in.imageMemoryBarrierCount = 1;
    dependency_in.pImageMemoryBarriers = &to_color;
    vkCmdPipelineBarrier2(cmd, &dependency_in);

    const VkClearValue clear_value{.color = {.float32 = {0.0F, 0.0F, 0.0F, 1.0F}}};
    VkRenderingAttachmentInfo color_attachment{};
    color_attachment.sType = VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO;
    color_attachment.imageView = image_view;
    color_attachment.imageLayout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
    color_attachment.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR;
    color_attachment.storeOp = VK_ATTACHMENT_STORE_OP_STORE;
    color_attachment.clearValue = clear_value;
    VkRenderingInfo render_info{};
    render_info.sType = VK_STRUCTURE_TYPE_RENDERING_INFO;
    render_info.renderArea = scissor;
    render_info.layerCount = 1;
    render_info.colorAttachmentCount = 1;
    render_info.pColorAttachments = &color_attachment;
    vkCmdBeginRendering(cmd, &render_info);

    vkCmdBindPipeline(cmd, VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline);
    const VkDeviceSize vertex_offset = 0;
    vkCmdBindVertexBuffers(cmd, 0, 1, &vertex_buffer, &vertex_offset);
    const glm::mat4 projection = glm::perspective(glm::radians(45.0F), 1.0F, 0.1F, 10.0F);
    const glm::mat4 view = glm::lookAt(glm::vec3{0.0F, 0.0F, 2.0F}, glm::vec3{0.0F}, glm::vec3{0.0F, 1.0F, 0.0F});
    const glm::mat4 flip_y = glm::scale(glm::mat4{1.0F}, glm::vec3{1.0F, -1.0F, 1.0F});
    const glm::mat4 mvp = flip_y * projection * view;
    vkCmdPushConstants(cmd, pipeline_layout, VK_SHADER_STAGE_VERTEX_BIT, 0, sizeof(glm::mat4), &mvp);
    vkCmdDraw(cmd, static_cast<std::uint32_t>(quad_vertices.size()), 1, 0, 0);
    vkCmdEndRendering(cmd);

    VkImageMemoryBarrier2 to_transfer{};
    to_transfer.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER_2;
    to_transfer.srcStageMask = VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT;
    to_transfer.srcAccessMask = VK_ACCESS_2_COLOR_ATTACHMENT_WRITE_BIT;
    to_transfer.dstStageMask = VK_PIPELINE_STAGE_2_TRANSFER_BIT;
    to_transfer.dstAccessMask = VK_ACCESS_2_TRANSFER_READ_BIT;
    to_transfer.oldLayout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
    to_transfer.newLayout = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
    to_transfer.image = image;
    to_transfer.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    to_transfer.subresourceRange.levelCount = 1;
    to_transfer.subresourceRange.layerCount = 1;
    VkDependencyInfo dependency_out{};
    dependency_out.sType = VK_STRUCTURE_TYPE_DEPENDENCY_INFO;
    dependency_out.imageMemoryBarrierCount = 1;
    dependency_out.pImageMemoryBarriers = &to_transfer;
    vkCmdPipelineBarrier2(cmd, &dependency_out);

    VkBufferImageCopy copy_region{};
    copy_region.imageSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    copy_region.imageSubresource.layerCount = 1;
    copy_region.imageExtent = VkExtent3D{.width = image_size, .height = image_size, .depth = 1};
    vkCmdCopyImageToBuffer(cmd, image, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, readback_buffer, 1, &copy_region);

    vk_check(vkEndCommandBuffer(cmd), "vkEndCommandBuffer");

    VkFenceCreateInfo fence_info{};
    fence_info.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
    VkFence fence = VK_NULL_HANDLE;
    vk_check(vkCreateFence(dev, &fence_info, nullptr, &fence), "vkCreateFence");
    VkSubmitInfo submit_info{};
    submit_info.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
    submit_info.commandBufferCount = 1;
    submit_info.pCommandBuffers = &cmd;
    vk_check(vkQueueSubmit(queue, 1, &submit_info, fence), "vkQueueSubmit");
    vk_check(vkWaitForFences(dev, 1, &fence, VK_TRUE, UINT64_MAX), "vkWaitForFences");

    // --- Read back and assert ---
    void* mapped = nullptr;
    vk_check(vkMapMemory(dev, readback_memory, 0, readback_size, 0, &mapped), "vkMapMemory(readback)");
    const auto* pixels = static_cast<const unsigned char*>(mapped);
    const auto pixel_at = [&pixels](std::uint32_t x_pos, std::uint32_t y_pos) {
        const std::size_t offset = (static_cast<std::size_t>(y_pos) * image_size + x_pos) * 4;
        return std::array<unsigned char, 4>{
            *std::next(pixels, static_cast<std::ptrdiff_t>(offset)),
            *std::next(pixels, static_cast<std::ptrdiff_t>(offset + 1)),
            *std::next(pixels, static_cast<std::ptrdiff_t>(offset + 2)),
            *std::next(pixels, static_cast<std::ptrdiff_t>(offset + 3)),
        };
    };

    // Center: the red quad (R ~ 0.9*255). Corner: the black clear color.
    const std::array<unsigned char, 4> center = pixel_at(image_size / 2, image_size / 2);
    const std::array<unsigned char, 4> corner = pixel_at(1, 1);
    EXPECT_GT(static_cast<int>(center.at(0)), 200) << "center pixel is not red - nothing rendered?";
    EXPECT_LT(static_cast<int>(center.at(1)), 60);
    EXPECT_LT(static_cast<int>(corner.at(0)), 10) << "corner pixel is not the clear color";
    EXPECT_LT(static_cast<int>(corner.at(1)), 10);

    std::size_t lit_pixels = 0;
    for (std::uint32_t y_pos = 0; y_pos < image_size; ++y_pos) {
        for (std::uint32_t x_pos = 0; x_pos < image_size; ++x_pos) {
            if (pixel_at(x_pos, y_pos).at(0) > 100) {
                ++lit_pixels;
            }
        }
    }
    // The quad covers roughly a quarter of the 64x64 image.
    EXPECT_GT(lit_pixels, static_cast<std::size_t>(image_size) * image_size / 8)
        << "too few lit pixels: " << lit_pixels;
    vkUnmapMemory(dev, readback_memory);

    // --- Cleanup ---
    vkDestroyFence(dev, fence, nullptr);
    vkDestroyCommandPool(dev, command_pool, nullptr);
    vkDestroyPipeline(dev, pipeline, nullptr);
    vkDestroyPipelineLayout(dev, pipeline_layout, nullptr);
    vkDestroyShaderModule(dev, vertex_module, nullptr);
    vkDestroyShaderModule(dev, fragment_module, nullptr);
    vkDestroyBuffer(dev, readback_buffer, nullptr);
    vkFreeMemory(dev, readback_memory, nullptr);
    vkDestroyBuffer(dev, vertex_buffer, nullptr);
    vkFreeMemory(dev, vertex_memory, nullptr);
    vkDestroyImageView(dev, image_view, nullptr);
    vkDestroyImage(dev, image, nullptr);
    vkFreeMemory(dev, image_memory, nullptr);
    vkb::destroy_device(device);
    vkb::destroy_instance(instance);
}

}  // namespace render_test
