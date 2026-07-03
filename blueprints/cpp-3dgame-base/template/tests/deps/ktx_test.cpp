#include <gtest/gtest.h>
#include <ktx.h>
#include <vulkan/vulkan_core.h>

namespace deps_test {

TEST(KtxTest, CreatesTexture) {
    ktxTextureCreateInfo info{};
    info.vkFormat = VK_FORMAT_R8G8B8A8_UNORM;
    info.baseWidth = 4;
    info.baseHeight = 4;
    info.baseDepth = 1;
    info.numDimensions = 2;
    info.numLevels = 1;
    info.numLayers = 1;
    info.numFaces = 1;
    info.isArray = KTX_FALSE;
    info.generateMipmaps = KTX_FALSE;

    ktxTexture2* texture = nullptr;
    ASSERT_EQ(ktxTexture2_Create(&info, KTX_TEXTURE_CREATE_ALLOC_STORAGE, &texture), KTX_SUCCESS);
    ASSERT_NE(texture, nullptr);
    ktxTexture_Destroy(ktxTexture(texture));
}

}  // namespace deps_test
