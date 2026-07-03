// Interactive demo: a rotating cube rendered with Vulkan, plus an ImGui menu.
//
// Running `just demo` verifies that the template's graphics stack really works
// end to end on this machine: SDL3 (window + mouse input), the Vulkan loader
// and driver (MoltenVK on macOS), vk-bootstrap (instance/device/swapchain),
// shaderc (GLSL compiled to SPIR-V at startup), VMA (vertex buffer memory),
// GLM (transforms), and Dear ImGui (menu overlay).
//
// Controls: drag with the left mouse button to rotate the cube, use the menu
// to toggle auto-rotation, Esc or closing the window quits. Pass
// `--auto-quit <seconds>` to exit automatically (used for smoke checks).
//
// VMA_IMPLEMENTATION and the VMA function-sourcing configuration are defined
// via target_compile_definitions in CMakeLists.txt.

#include <SDL3/SDL_error.h>
#include <SDL3/SDL_events.h>
#include <SDL3/SDL_init.h>
#include <SDL3/SDL_keycode.h>
#include <SDL3/SDL_mouse.h>
#include <SDL3/SDL_video.h>
#include <SDL3/SDL_vulkan.h>
#include <VkBootstrap.h>
#include <algorithm>
#include <array>
#include <charconv>
#include <chrono>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <exception>
#include <format>
#include <glm/ext/matrix_clip_space.hpp>
#include <glm/ext/matrix_float4x4.hpp>
#include <glm/ext/matrix_transform.hpp>
#include <glm/ext/vector_float3.hpp>
#include <glm/trigonometric.hpp>
#include <imgui.h>
#include <imgui_impl_vulkan.h>
#include <print>
#include <shaderc/shaderc.h>
#include <shaderc/shaderc.hpp>
#include <shaderc/status.h>
#include <span>
#include <stdexcept>
#include <string>
#include <string_view>
#include <system_error>
#include <vector>
#include <vk_mem_alloc.h>
#include <vulkan/vulkan_core.h>

namespace demo {
namespace {

constexpr int window_width = 1280;
constexpr int window_height = 720;
constexpr std::uint32_t frames_in_flight = 2;

constexpr std::string_view vertex_shader_glsl = R"(#version 450
layout(location = 0) in vec3 in_position;
layout(location = 1) in vec3 in_color;
layout(push_constant) uniform PushConstants { mat4 mvp; } push;
layout(location = 0) out vec3 frag_color;
void main() {
    gl_Position = push.mvp * vec4(in_position, 1.0);
    frag_color = in_color;
}
)";

constexpr std::string_view fragment_shader_glsl = R"(#version 450
layout(location = 0) in vec3 frag_color;
layout(location = 0) out vec4 out_color;
void main() {
    out_color = vec4(frag_color, 1.0);
}
)";

struct Vertex {
    std::array<float, 3> position;
    std::array<float, 3> color;
};

// One cube face: two counter-clockwise triangles sharing a color.
constexpr std::array<Vertex, 6> make_face(const std::array<std::array<float, 3>, 4>& corners,
                                          const std::array<float, 3>& color) {
    return {
        Vertex{.position = corners.at(0), .color = color},
        Vertex{.position = corners.at(1), .color = color},
        Vertex{.position = corners.at(2), .color = color},
        Vertex{.position = corners.at(0), .color = color},
        Vertex{.position = corners.at(2), .color = color},
        Vertex{.position = corners.at(3), .color = color},
    };
}

constexpr std::array<Vertex, 36> make_cube_vertices() {
    constexpr std::array<std::array<std::array<float, 3>, 4>, 6> faces{{
        {{{-0.5F, -0.5F, 0.5F}, {0.5F, -0.5F, 0.5F}, {0.5F, 0.5F, 0.5F}, {-0.5F, 0.5F, 0.5F}}},
        {{{0.5F, -0.5F, -0.5F}, {-0.5F, -0.5F, -0.5F}, {-0.5F, 0.5F, -0.5F}, {0.5F, 0.5F, -0.5F}}},
        {{{-0.5F, -0.5F, -0.5F}, {-0.5F, -0.5F, 0.5F}, {-0.5F, 0.5F, 0.5F}, {-0.5F, 0.5F, -0.5F}}},
        {{{0.5F, -0.5F, 0.5F}, {0.5F, -0.5F, -0.5F}, {0.5F, 0.5F, -0.5F}, {0.5F, 0.5F, 0.5F}}},
        {{{-0.5F, 0.5F, 0.5F}, {0.5F, 0.5F, 0.5F}, {0.5F, 0.5F, -0.5F}, {-0.5F, 0.5F, -0.5F}}},
        {{{-0.5F, -0.5F, -0.5F}, {0.5F, -0.5F, -0.5F}, {0.5F, -0.5F, 0.5F}, {-0.5F, -0.5F, 0.5F}}},
    }};
    constexpr std::array<std::array<float, 3>, 6> colors{{
        {0.9F, 0.2F, 0.2F},
        {0.2F, 0.9F, 0.2F},
        {0.2F, 0.3F, 0.9F},
        {0.9F, 0.9F, 0.2F},
        {0.9F, 0.2F, 0.9F},
        {0.2F, 0.9F, 0.9F},
    }};
    std::array<Vertex, 36> vertices{};
    for (std::size_t face_index = 0; face_index < faces.size(); ++face_index) {
        const std::array<Vertex, 6> face = make_face(faces.at(face_index), colors.at(face_index));
        for (std::size_t vertex_index = 0; vertex_index < face.size(); ++vertex_index) {
            vertices.at((face_index * face.size()) + vertex_index) = face.at(vertex_index);
        }
    }
    return vertices;
}

constexpr std::array<Vertex, 36> cube_vertices = make_cube_vertices();

void vk_check(VkResult result, std::string_view what) {
    if (result != VK_SUCCESS) {
        throw std::runtime_error(std::format("{} failed (VkResult {})", what, static_cast<int>(result)));
    }
}

std::vector<std::uint32_t> compile_shader(std::string_view source, shaderc_shader_kind kind, std::string_view name) {
    const shaderc::Compiler compiler;
    const shaderc::CompileOptions options;
    const shaderc::SpvCompilationResult result =
        compiler.CompileGlslToSpv(std::string{source}, kind, std::string{name}.c_str(), options);
    if (result.GetCompilationStatus() != shaderc_compilation_status_success) {
        throw std::runtime_error(std::format("shader compilation of {} failed: {}", name, result.GetErrorMessage()));
    }
    return {result.cbegin(), result.cend()};
}

struct FrameSync {
    VkCommandPool command_pool = VK_NULL_HANDLE;
    VkCommandBuffer command_buffer = VK_NULL_HANDLE;
    VkSemaphore image_available = VK_NULL_HANDLE;
    VkFence in_flight = VK_NULL_HANDLE;
};

class DemoApp {
   public:
    void init_window() {
        if (!SDL_Init(SDL_INIT_VIDEO)) {
            throw std::runtime_error(std::format("SDL_Init failed: {}", SDL_GetError()));
        }
        window_ = SDL_CreateWindow("Vulkan Cube Demo",
                                   window_width,
                                   window_height,
                                   SDL_WINDOW_VULKAN | SDL_WINDOW_RESIZABLE | SDL_WINDOW_HIGH_PIXEL_DENSITY);
        if (window_ == nullptr) {
            throw std::runtime_error(std::format("SDL_CreateWindow failed: {}", SDL_GetError()));
        }
    }

    void init_vulkan() {
        vkb::InstanceBuilder builder{vkGetInstanceProcAddr};
        auto instance_result = builder.set_app_name("Vulkan Cube Demo").require_api_version(1, 3, 0).build();
        if (!instance_result) {
            throw std::runtime_error(
                std::format("Vulkan instance creation failed: {}", instance_result.error().message()));
        }
        instance_ = instance_result.value();

        if (!SDL_Vulkan_CreateSurface(window_, instance_.instance, nullptr, &surface_)) {
            throw std::runtime_error(std::format("SDL_Vulkan_CreateSurface failed: {}", SDL_GetError()));
        }

        VkPhysicalDeviceVulkan13Features features13{};
        features13.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_3_FEATURES;
        features13.dynamicRendering = VK_TRUE;
        features13.synchronization2 = VK_TRUE;

        vkb::PhysicalDeviceSelector selector{instance_};
        auto physical_result =
            selector.set_surface(surface_).set_minimum_version(1, 3).set_required_features_13(features13).select();
        if (!physical_result) {
            throw std::runtime_error(
                std::format("no suitable Vulkan 1.3 GPU found: {}", physical_result.error().message()));
        }
        physical_device_ = physical_result.value();

        auto device_result = vkb::DeviceBuilder{physical_device_}.build();
        if (!device_result) {
            throw std::runtime_error(std::format("Vulkan device creation failed: {}", device_result.error().message()));
        }
        device_ = device_result.value();

        auto queue_result = device_.get_queue(vkb::QueueType::graphics);
        auto queue_family_result = device_.get_queue_index(vkb::QueueType::graphics);
        if (!queue_result || !queue_family_result) {
            throw std::runtime_error("no graphics queue available");
        }
        graphics_queue_ = queue_result.value();
        graphics_queue_family_ = queue_family_result.value();

        VmaAllocatorCreateInfo allocator_info{};
        allocator_info.physicalDevice = physical_device_.physical_device;
        allocator_info.device = device_.device;
        allocator_info.instance = instance_.instance;
        allocator_info.vulkanApiVersion = VK_API_VERSION_1_3;
        vk_check(vmaCreateAllocator(&allocator_info, &allocator_), "vmaCreateAllocator");
    }

    void create_swapchain() {
        int pixel_width = 0;
        int pixel_height = 0;
        if (!SDL_GetWindowSizeInPixels(window_, &pixel_width, &pixel_height)) {
            throw std::runtime_error(std::format("SDL_GetWindowSizeInPixels failed: {}", SDL_GetError()));
        }
        auto swapchain_result =
            vkb::SwapchainBuilder{device_}
                .set_desired_format(VkSurfaceFormatKHR{.format = VK_FORMAT_B8G8R8A8_UNORM,
                                                       .colorSpace = VK_COLOR_SPACE_SRGB_NONLINEAR_KHR})
                .set_desired_present_mode(VK_PRESENT_MODE_FIFO_KHR)
                .set_desired_extent(static_cast<std::uint32_t>(pixel_width), static_cast<std::uint32_t>(pixel_height))
                .set_old_swapchain(swapchain_)
                .build();
        if (!swapchain_result) {
            throw std::runtime_error(std::format("swapchain creation failed: {}", swapchain_result.error().message()));
        }
        vkb::destroy_swapchain(swapchain_);
        swapchain_ = swapchain_result.value();

        auto images_result = swapchain_.get_images();
        auto views_result = swapchain_.get_image_views();
        if (!images_result || !views_result) {
            throw std::runtime_error("failed to obtain swapchain images");
        }
        swapchain_images_ = images_result.value();
        swapchain_image_views_ = views_result.value();

        for (VkSemaphore semaphore : render_finished_) {
            vkDestroySemaphore(device_.device, semaphore, nullptr);
        }
        render_finished_.assign(swapchain_images_.size(), VK_NULL_HANDLE);
        for (auto& semaphore : render_finished_) {
            VkSemaphoreCreateInfo semaphore_info{};
            semaphore_info.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;
            vk_check(vkCreateSemaphore(device_.device, &semaphore_info, nullptr, &semaphore), "vkCreateSemaphore");
        }
    }

    void create_vertex_buffer() {
        VkBufferCreateInfo buffer_info{};
        buffer_info.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
        buffer_info.size = sizeof(cube_vertices);
        buffer_info.usage = VK_BUFFER_USAGE_VERTEX_BUFFER_BIT;
        buffer_info.sharingMode = VK_SHARING_MODE_EXCLUSIVE;

        VmaAllocationCreateInfo allocation_info{};
        allocation_info.usage = VMA_MEMORY_USAGE_AUTO;
        allocation_info.flags =
            static_cast<VmaAllocationCreateFlags>(VMA_ALLOCATION_CREATE_HOST_ACCESS_SEQUENTIAL_WRITE_BIT) |
            static_cast<VmaAllocationCreateFlags>(VMA_ALLOCATION_CREATE_MAPPED_BIT);

        VmaAllocationInfo mapped_info{};
        vk_check(vmaCreateBuffer(
                     allocator_, &buffer_info, &allocation_info, &vertex_buffer_, &vertex_allocation_, &mapped_info),
                 "vmaCreateBuffer");
        auto* mapped_vertices = static_cast<Vertex*>(mapped_info.pMappedData);
        std::ranges::copy(cube_vertices, mapped_vertices);
    }

    void create_pipeline() {
        const std::vector<std::uint32_t> vertex_spirv =
            compile_shader(vertex_shader_glsl, shaderc_glsl_vertex_shader, "cube.vert");
        const std::vector<std::uint32_t> fragment_spirv =
            compile_shader(fragment_shader_glsl, shaderc_glsl_fragment_shader, "cube.frag");

        VkShaderModule vertex_module = create_shader_module(vertex_spirv, "vertex");
        VkShaderModule fragment_module = create_shader_module(fragment_spirv, "fragment");

        VkPushConstantRange push_range{};
        push_range.stageFlags = VK_SHADER_STAGE_VERTEX_BIT;
        push_range.offset = 0;
        push_range.size = sizeof(glm::mat4);

        VkPipelineLayoutCreateInfo layout_info{};
        layout_info.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
        layout_info.pushConstantRangeCount = 1;
        layout_info.pPushConstantRanges = &push_range;
        vk_check(vkCreatePipelineLayout(device_.device, &layout_info, nullptr, &pipeline_layout_),
                 "vkCreatePipelineLayout");

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
        binding.binding = 0;
        binding.stride = sizeof(Vertex);
        binding.inputRate = VK_VERTEX_INPUT_RATE_VERTEX;

        const std::array<VkVertexInputAttributeDescription, 2> attributes{{
            VkVertexInputAttributeDescription{
                .location = 0,
                .binding = 0,
                .format = VK_FORMAT_R32G32B32_SFLOAT,
                .offset = offsetof(Vertex, position),
            },
            VkVertexInputAttributeDescription{
                .location = 1,
                .binding = 0,
                .format = VK_FORMAT_R32G32B32_SFLOAT,
                .offset = offsetof(Vertex, color),
            },
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

        VkPipelineViewportStateCreateInfo viewport_state{};
        viewport_state.sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
        viewport_state.viewportCount = 1;
        viewport_state.scissorCount = 1;

        VkPipelineRasterizationStateCreateInfo rasterization{};
        rasterization.sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
        rasterization.polygonMode = VK_POLYGON_MODE_FILL;
        rasterization.cullMode = VK_CULL_MODE_BACK_BIT;
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

        const std::array<VkDynamicState, 2> dynamic_states{VK_DYNAMIC_STATE_VIEWPORT, VK_DYNAMIC_STATE_SCISSOR};
        VkPipelineDynamicStateCreateInfo dynamic_state{};
        dynamic_state.sType = VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO;
        dynamic_state.dynamicStateCount = static_cast<std::uint32_t>(dynamic_states.size());
        dynamic_state.pDynamicStates = dynamic_states.data();

        const VkFormat color_format = swapchain_.image_format;
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
        pipeline_info.pDynamicState = &dynamic_state;
        pipeline_info.layout = pipeline_layout_;
        vk_check(vkCreateGraphicsPipelines(device_.device, VK_NULL_HANDLE, 1, &pipeline_info, nullptr, &pipeline_),
                 "vkCreateGraphicsPipelines");

        vkDestroyShaderModule(device_.device, vertex_module, nullptr);
        vkDestroyShaderModule(device_.device, fragment_module, nullptr);
    }

    void create_frame_sync() {
        for (auto& frame : frames_) {
            VkCommandPoolCreateInfo pool_info{};
            pool_info.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
            pool_info.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
            pool_info.queueFamilyIndex = graphics_queue_family_;
            vk_check(vkCreateCommandPool(device_.device, &pool_info, nullptr, &frame.command_pool),
                     "vkCreateCommandPool");

            VkCommandBufferAllocateInfo alloc_info{};
            alloc_info.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
            alloc_info.commandPool = frame.command_pool;
            alloc_info.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
            alloc_info.commandBufferCount = 1;
            vk_check(vkAllocateCommandBuffers(device_.device, &alloc_info, &frame.command_buffer),
                     "vkAllocateCommandBuffers");

            VkSemaphoreCreateInfo semaphore_info{};
            semaphore_info.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;
            vk_check(vkCreateSemaphore(device_.device, &semaphore_info, nullptr, &frame.image_available),
                     "vkCreateSemaphore");

            VkFenceCreateInfo fence_info{};
            fence_info.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
            fence_info.flags = VK_FENCE_CREATE_SIGNALED_BIT;
            vk_check(vkCreateFence(device_.device, &fence_info, nullptr, &frame.in_flight), "vkCreateFence");
        }
    }

    void init_imgui() {
        IMGUI_CHECKVERSION();
        ImGui::CreateContext();
        ImGui::StyleColorsDark();

        VkDescriptorPoolSize pool_size{};
        pool_size.type = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
        pool_size.descriptorCount = 8;
        VkDescriptorPoolCreateInfo pool_info{};
        pool_info.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO;
        pool_info.flags = VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT;
        pool_info.maxSets = 8;
        pool_info.poolSizeCount = 1;
        pool_info.pPoolSizes = &pool_size;
        vk_check(vkCreateDescriptorPool(device_.device, &pool_info, nullptr, &imgui_pool_), "vkCreateDescriptorPool");

        const VkFormat color_format = swapchain_.image_format;
        ImGui_ImplVulkan_InitInfo init_info{
            .Instance = instance_.instance,
            .PhysicalDevice = physical_device_.physical_device,
            .Device = device_.device,
            .QueueFamily = graphics_queue_family_,
            .Queue = graphics_queue_,
            .DescriptorPool = imgui_pool_,
            .RenderPass = VK_NULL_HANDLE,
            .MinImageCount = frames_in_flight,
            .ImageCount = static_cast<std::uint32_t>(swapchain_images_.size()),
            .MSAASamples = VK_SAMPLE_COUNT_1_BIT,
            .PipelineCache = VK_NULL_HANDLE,
            .Subpass = 0,
            .UseDynamicRendering = true,
            .PipelineRenderingCreateInfo =
                VkPipelineRenderingCreateInfoKHR{
                    .sType = VK_STRUCTURE_TYPE_PIPELINE_RENDERING_CREATE_INFO_KHR,
                    .pNext = nullptr,
                    .viewMask = 0,
                    .colorAttachmentCount = 1,
                    .pColorAttachmentFormats = &color_format,
                    .depthAttachmentFormat = VK_FORMAT_UNDEFINED,
                    .stencilAttachmentFormat = VK_FORMAT_UNDEFINED,
                },
            .Allocator = nullptr,
            .CheckVkResultFn = nullptr,
            .MinAllocationSize = 0,
        };
        if (!ImGui_ImplVulkan_Init(&init_info)) {
            throw std::runtime_error("ImGui_ImplVulkan_Init failed");
        }
        if (!ImGui_ImplVulkan_CreateFontsTexture()) {
            throw std::runtime_error("ImGui_ImplVulkan_CreateFontsTexture failed");
        }
    }

    void run(std::uint32_t auto_quit_seconds) {
        using clock = std::chrono::steady_clock;
        const clock::time_point start_time = clock::now();
        clock::time_point last_frame = start_time;

        bool running = true;
        while (running) {
            SDL_Event event;
            while (SDL_PollEvent(&event)) {
                forward_event_to_imgui(event);
                handle_event(event, running);
            }

            const clock::time_point now = clock::now();
            const float delta_seconds = std::chrono::duration<float>(now - last_frame).count();
            last_frame = now;

            if (auto_rotate_ && !dragging_) {
                yaw_ += delta_seconds * rotation_speed_;
            }

            update_imgui_frame_state(delta_seconds);
            ImGui_ImplVulkan_NewFrame();
            ImGui::NewFrame();
            build_menu(running);
            ImGui::Render();

            draw_frame(compute_mvp());

            if (auto_quit_seconds > 0) {
                const float elapsed_seconds = std::chrono::duration<float>(now - start_time).count();
                if (elapsed_seconds >= static_cast<float>(auto_quit_seconds)) {
                    running = false;
                }
            }
        }
    }

    void shutdown() {
        vk_check(vkDeviceWaitIdle(device_.device), "vkDeviceWaitIdle");
        ImGui_ImplVulkan_Shutdown();
        ImGui::DestroyContext();
        vkDestroyDescriptorPool(device_.device, imgui_pool_, nullptr);
        for (const FrameSync& frame : frames_) {
            vkDestroyFence(device_.device, frame.in_flight, nullptr);
            vkDestroySemaphore(device_.device, frame.image_available, nullptr);
            vkDestroyCommandPool(device_.device, frame.command_pool, nullptr);
        }
        for (VkSemaphore semaphore : render_finished_) {
            vkDestroySemaphore(device_.device, semaphore, nullptr);
        }
        vkDestroyPipeline(device_.device, pipeline_, nullptr);
        vkDestroyPipelineLayout(device_.device, pipeline_layout_, nullptr);
        vmaDestroyBuffer(allocator_, vertex_buffer_, vertex_allocation_);
        vmaDestroyAllocator(allocator_);
        destroy_swapchain_views();
        vkb::destroy_swapchain(swapchain_);
        vkb::destroy_surface(instance_, surface_);
        vkb::destroy_device(device_);
        vkb::destroy_instance(instance_);
        SDL_DestroyWindow(window_);
        SDL_Quit();
    }

    [[nodiscard]] std::uint64_t rendered_frames() const { return frames_rendered_; }

   private:
    [[nodiscard]] VkShaderModule create_shader_module(const std::vector<std::uint32_t>& spirv,
                                                      std::string_view what) const {
        VkShaderModuleCreateInfo module_info{};
        module_info.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
        module_info.codeSize = spirv.size() * sizeof(std::uint32_t);
        module_info.pCode = spirv.data();
        VkShaderModule shader_module = VK_NULL_HANDLE;
        vk_check(vkCreateShaderModule(device_.device, &module_info, nullptr, &shader_module),
                 std::format("vkCreateShaderModule({})", what));
        return shader_module;
    }

    void destroy_swapchain_views() {
        for (VkImageView view : swapchain_image_views_) {
            vkDestroyImageView(device_.device, view, nullptr);
        }
        swapchain_image_views_.clear();
    }

    void recreate_swapchain() {
        vk_check(vkDeviceWaitIdle(device_.device), "vkDeviceWaitIdle");
        destroy_swapchain_views();
        create_swapchain();
    }

    // Minimal SDL3 -> ImGui input bridge: the demo menu only needs mouse
    // events, so the full imgui_impl_sdl3 platform backend is not required.
    static void forward_event_to_imgui(const SDL_Event& event) {
        ImGuiIO& imgui_io = ImGui::GetIO();
        switch (event.type) {
            case SDL_EVENT_MOUSE_MOTION:
                imgui_io.AddMousePosEvent(event.motion.x, event.motion.y);
                break;
            case SDL_EVENT_MOUSE_BUTTON_DOWN:
            case SDL_EVENT_MOUSE_BUTTON_UP: {
                int button = -1;
                if (event.button.button == SDL_BUTTON_LEFT) {
                    button = ImGuiMouseButton_Left;
                }
                if (event.button.button == SDL_BUTTON_RIGHT) {
                    button = ImGuiMouseButton_Right;
                }
                if (event.button.button == SDL_BUTTON_MIDDLE) {
                    button = ImGuiMouseButton_Middle;
                }
                if (button >= 0) {
                    imgui_io.AddMouseButtonEvent(button, event.type == SDL_EVENT_MOUSE_BUTTON_DOWN);
                }
                break;
            }
            case SDL_EVENT_MOUSE_WHEEL:
                imgui_io.AddMouseWheelEvent(event.wheel.x, event.wheel.y);
                break;
            default:
                break;
        }
    }

    void handle_event(const SDL_Event& event, bool& running) {
        const ImGuiIO& imgui_io = ImGui::GetIO();
        switch (event.type) {
            case SDL_EVENT_QUIT:
                running = false;
                break;
            case SDL_EVENT_KEY_DOWN:
                if (event.key.key == SDLK_ESCAPE) {
                    running = false;
                }
                break;
            case SDL_EVENT_MOUSE_BUTTON_DOWN:
                if (event.button.button == SDL_BUTTON_LEFT && !imgui_io.WantCaptureMouse) {
                    dragging_ = true;
                }
                break;
            case SDL_EVENT_MOUSE_BUTTON_UP:
                if (event.button.button == SDL_BUTTON_LEFT) {
                    dragging_ = false;
                }
                break;
            case SDL_EVENT_MOUSE_MOTION:
                if (dragging_) {
                    yaw_ += event.motion.xrel * 0.01F;
                    pitch_ += event.motion.yrel * 0.01F;
                }
                break;
            default:
                break;
        }
    }

    void update_imgui_frame_state(float delta_seconds) const {
        ImGuiIO& imgui_io = ImGui::GetIO();
        int logical_width = 0;
        int logical_height = 0;
        SDL_GetWindowSize(window_, &logical_width, &logical_height);
        int pixel_width = 0;
        int pixel_height = 0;
        SDL_GetWindowSizeInPixels(window_, &pixel_width, &pixel_height);
        imgui_io.DisplaySize = ImVec2(static_cast<float>(logical_width), static_cast<float>(logical_height));
        if (logical_width > 0 && logical_height > 0) {
            imgui_io.DisplayFramebufferScale =
                ImVec2(static_cast<float>(pixel_width) / static_cast<float>(logical_width),
                       static_cast<float>(pixel_height) / static_cast<float>(logical_height));
        }
        imgui_io.DeltaTime = delta_seconds > 0.0F ? delta_seconds : 1.0F / 60.0F;
    }

    void build_menu(bool& running) {
        ImGui::Begin("Demo Menu");
        ImGui::TextUnformatted("Vulkan cube demo - the stack is alive!");
        ImGui::Checkbox("Auto-rotate", &auto_rotate_);
        ImGui::SliderFloat("Speed", &rotation_speed_, 0.0F, 4.0F);
        ImGui::TextUnformatted("Drag with the left mouse button to rotate.");
        ImGui::TextUnformatted(std::format("{:.1f} FPS", static_cast<double>(ImGui::GetIO().Framerate)).c_str());
        if (ImGui::Button("Quit")) {
            running = false;
        }
        ImGui::End();
    }

    [[nodiscard]] glm::mat4 compute_mvp() const {
        const float aspect = swapchain_.extent.height > 0 ? static_cast<float>(swapchain_.extent.width) /
                                                                static_cast<float>(swapchain_.extent.height)
                                                          : 1.0F;
        const glm::mat4 projection = glm::perspective(glm::radians(45.0F), aspect, 0.1F, 10.0F);
        // Vulkan's clip space Y points down; flip it after projection.
        const glm::mat4 flip_y = glm::scale(glm::mat4{1.0F}, glm::vec3{1.0F, -1.0F, 1.0F});
        const glm::mat4 view = glm::lookAt(glm::vec3{0.0F, 0.0F, 3.0F}, glm::vec3{0.0F}, glm::vec3{0.0F, 1.0F, 0.0F});
        glm::mat4 model = glm::rotate(glm::mat4{1.0F}, pitch_, glm::vec3{1.0F, 0.0F, 0.0F});
        model = glm::rotate(model, yaw_, glm::vec3{0.0F, 1.0F, 0.0F});
        return flip_y * projection * view * model;
    }

    void record_and_submit(std::uint32_t image_index, const glm::mat4& mvp) {
        const FrameSync& frame = frames_.at(frame_index_);
        VkCommandBuffer cmd = frame.command_buffer;
        vk_check(vkResetCommandBuffer(cmd, 0), "vkResetCommandBuffer");

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
        to_color.image = swapchain_images_.at(image_index);
        to_color.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
        to_color.subresourceRange.levelCount = 1;
        to_color.subresourceRange.layerCount = 1;
        VkDependencyInfo dependency_in{};
        dependency_in.sType = VK_STRUCTURE_TYPE_DEPENDENCY_INFO;
        dependency_in.imageMemoryBarrierCount = 1;
        dependency_in.pImageMemoryBarriers = &to_color;
        vkCmdPipelineBarrier2(cmd, &dependency_in);

        const VkClearValue clear_value{.color = {.float32 = {0.05F, 0.06F, 0.09F, 1.0F}}};
        VkRenderingAttachmentInfo color_attachment{};
        color_attachment.sType = VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO;
        color_attachment.imageView = swapchain_image_views_.at(image_index);
        color_attachment.imageLayout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
        color_attachment.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR;
        color_attachment.storeOp = VK_ATTACHMENT_STORE_OP_STORE;
        color_attachment.clearValue = clear_value;

        VkRenderingInfo rendering_info{};
        rendering_info.sType = VK_STRUCTURE_TYPE_RENDERING_INFO;
        rendering_info.renderArea = VkRect2D{.offset = {.x = 0, .y = 0}, .extent = swapchain_.extent};
        rendering_info.layerCount = 1;
        rendering_info.colorAttachmentCount = 1;
        rendering_info.pColorAttachments = &color_attachment;
        vkCmdBeginRendering(cmd, &rendering_info);

        VkViewport viewport{};
        viewport.width = static_cast<float>(swapchain_.extent.width);
        viewport.height = static_cast<float>(swapchain_.extent.height);
        viewport.maxDepth = 1.0F;
        vkCmdSetViewport(cmd, 0, 1, &viewport);
        const VkRect2D scissor{.offset = {.x = 0, .y = 0}, .extent = swapchain_.extent};
        vkCmdSetScissor(cmd, 0, 1, &scissor);

        vkCmdBindPipeline(cmd, VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline_);
        const VkDeviceSize vertex_offset = 0;
        vkCmdBindVertexBuffers(cmd, 0, 1, &vertex_buffer_, &vertex_offset);
        vkCmdPushConstants(cmd, pipeline_layout_, VK_SHADER_STAGE_VERTEX_BIT, 0, sizeof(glm::mat4), &mvp);
        vkCmdDraw(cmd, static_cast<std::uint32_t>(cube_vertices.size()), 1, 0, 0);

        ImGui_ImplVulkan_RenderDrawData(ImGui::GetDrawData(), cmd);

        vkCmdEndRendering(cmd);

        VkImageMemoryBarrier2 to_present{};
        to_present.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER_2;
        to_present.srcStageMask = VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT;
        to_present.srcAccessMask = VK_ACCESS_2_COLOR_ATTACHMENT_WRITE_BIT;
        to_present.dstStageMask = VK_PIPELINE_STAGE_2_BOTTOM_OF_PIPE_BIT;
        to_present.oldLayout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
        to_present.newLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;
        to_present.image = swapchain_images_.at(image_index);
        to_present.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
        to_present.subresourceRange.levelCount = 1;
        to_present.subresourceRange.layerCount = 1;
        VkDependencyInfo dependency_out{};
        dependency_out.sType = VK_STRUCTURE_TYPE_DEPENDENCY_INFO;
        dependency_out.imageMemoryBarrierCount = 1;
        dependency_out.pImageMemoryBarriers = &to_present;
        vkCmdPipelineBarrier2(cmd, &dependency_out);

        vk_check(vkEndCommandBuffer(cmd), "vkEndCommandBuffer");

        VkSemaphoreSubmitInfo wait_info{};
        wait_info.sType = VK_STRUCTURE_TYPE_SEMAPHORE_SUBMIT_INFO;
        wait_info.semaphore = frame.image_available;
        wait_info.stageMask = VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT;
        VkSemaphoreSubmitInfo signal_info{};
        signal_info.sType = VK_STRUCTURE_TYPE_SEMAPHORE_SUBMIT_INFO;
        signal_info.semaphore = render_finished_.at(image_index);
        signal_info.stageMask = VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT;
        VkCommandBufferSubmitInfo cmd_info{};
        cmd_info.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_SUBMIT_INFO;
        cmd_info.commandBuffer = cmd;

        VkSubmitInfo2 submit_info{};
        submit_info.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO_2;
        submit_info.waitSemaphoreInfoCount = 1;
        submit_info.pWaitSemaphoreInfos = &wait_info;
        submit_info.commandBufferInfoCount = 1;
        submit_info.pCommandBufferInfos = &cmd_info;
        submit_info.signalSemaphoreInfoCount = 1;
        submit_info.pSignalSemaphoreInfos = &signal_info;
        vk_check(vkQueueSubmit2(graphics_queue_, 1, &submit_info, frame.in_flight), "vkQueueSubmit2");
    }

    void draw_frame(const glm::mat4& mvp) {
        const FrameSync& frame = frames_.at(frame_index_);
        vk_check(vkWaitForFences(device_.device, 1, &frame.in_flight, VK_TRUE, UINT64_MAX), "vkWaitForFences");

        std::uint32_t image_index = 0;
        const VkResult acquire_result = vkAcquireNextImageKHR(
            device_.device, swapchain_.swapchain, UINT64_MAX, frame.image_available, VK_NULL_HANDLE, &image_index);
        if (acquire_result == VK_ERROR_OUT_OF_DATE_KHR) {
            recreate_swapchain();
            return;
        }
        if (acquire_result != VK_SUCCESS && acquire_result != VK_SUBOPTIMAL_KHR) {
            vk_check(acquire_result, "vkAcquireNextImageKHR");
        }

        vk_check(vkResetFences(device_.device, 1, &frame.in_flight), "vkResetFences");
        record_and_submit(image_index, mvp);

        VkPresentInfoKHR present_info{};
        present_info.sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
        present_info.waitSemaphoreCount = 1;
        present_info.pWaitSemaphores = &render_finished_.at(image_index);
        present_info.swapchainCount = 1;
        present_info.pSwapchains = &swapchain_.swapchain;
        present_info.pImageIndices = &image_index;
        const VkResult present_result = vkQueuePresentKHR(graphics_queue_, &present_info);
        if (present_result == VK_ERROR_OUT_OF_DATE_KHR || present_result == VK_SUBOPTIMAL_KHR) {
            recreate_swapchain();
        } else {
            vk_check(present_result, "vkQueuePresentKHR");
        }

        frames_rendered_ += 1;
        frame_index_ = (frame_index_ + 1) % frames_in_flight;
    }

    SDL_Window* window_ = nullptr;
    vkb::Instance instance_;
    VkSurfaceKHR surface_ = VK_NULL_HANDLE;
    vkb::PhysicalDevice physical_device_;
    vkb::Device device_;
    VkQueue graphics_queue_ = VK_NULL_HANDLE;
    std::uint32_t graphics_queue_family_ = 0;

    vkb::Swapchain swapchain_;
    std::vector<VkImage> swapchain_images_;
    std::vector<VkImageView> swapchain_image_views_;
    std::vector<VkSemaphore> render_finished_;

    VmaAllocator allocator_ = VK_NULL_HANDLE;
    VkBuffer vertex_buffer_ = VK_NULL_HANDLE;
    VmaAllocation vertex_allocation_ = VK_NULL_HANDLE;

    VkPipelineLayout pipeline_layout_ = VK_NULL_HANDLE;
    VkPipeline pipeline_ = VK_NULL_HANDLE;
    VkDescriptorPool imgui_pool_ = VK_NULL_HANDLE;

    std::array<FrameSync, frames_in_flight> frames_{};
    std::uint32_t frame_index_ = 0;

    bool auto_rotate_ = true;
    float rotation_speed_ = 1.0F;
    float yaw_ = 0.6F;
    float pitch_ = 0.4F;
    bool dragging_ = false;
    std::uint64_t frames_rendered_ = 0;
};

std::uint32_t parse_auto_quit(std::span<char*> args) {
    const std::vector<std::string_view> arg_views{args.begin(), args.end()};
    for (std::size_t idx = 1; idx < arg_views.size(); ++idx) {
        if (arg_views.at(idx) == "--auto-quit") {
            if (idx + 1 >= arg_views.size()) {
                throw std::runtime_error("--auto-quit requires a value in seconds");
            }
            const std::string_view value = arg_views.at(idx + 1);
            std::uint32_t seconds = 0;
            const auto [ptr, err] = std::from_chars(value.begin(), value.end(), seconds);
            if (err != std::errc{} || ptr != value.end() || seconds == 0) {
                throw std::runtime_error(
                    std::format("invalid --auto-quit value '{}': expected positive seconds", value));
            }
            return seconds;
        }
    }
    return 0;
}

}  // namespace
}  // namespace demo

int main(int argc, char** argv) {
    try {
        const std::span<char*> arguments{argv, static_cast<std::size_t>(argc)};
        const std::uint32_t auto_quit_seconds = demo::parse_auto_quit(arguments);

        demo::DemoApp app;
        app.init_window();
        app.init_vulkan();
        app.create_swapchain();
        app.create_vertex_buffer();
        app.create_pipeline();
        app.create_frame_sync();
        app.init_imgui();

        std::println("demo: entering main loop (Esc or the Quit button exits)");
        app.run(auto_quit_seconds);
        app.shutdown();
        std::println("demo: clean exit after {} rendered frames", app.rendered_frames());
        return 0;
    } catch (const std::exception& error) {
        std::println(stderr, "demo: fatal error: {}", error.what());
        return 1;
    }
}
