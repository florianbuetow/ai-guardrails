#include <gtest/gtest.h>

// tinygltf is header-only; exactly one TU provides the implementation.
#define TINYGLTF_IMPLEMENTATION
#define STB_IMAGE_IMPLEMENTATION
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include <tiny_gltf.h>

#include <string>

namespace deps_test {

TEST(TinygltfTest, ParsesMinimalAsset) {
    const std::string gltf = R"({"asset": {"version": "2.0"}})";
    tinygltf::TinyGLTF loader;
    tinygltf::Model model;
    std::string err;
    std::string warn;
    const bool ok =
        loader.LoadASCIIFromString(&model, &err, &warn, gltf.c_str(), static_cast<unsigned int>(gltf.size()), "");
    EXPECT_TRUE(ok) << err;
    EXPECT_EQ(model.asset.version, "2.0");
}

}  // namespace deps_test
