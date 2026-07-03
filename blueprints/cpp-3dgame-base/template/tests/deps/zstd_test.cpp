#include <gtest/gtest.h>
#include <zstd.h>

#include <string>
#include <vector>

namespace deps_test {

TEST(ZstdTest, RoundTripsBuffer) {
    std::string input;
    for (int i = 0; i < 100; ++i) {
        input += "compress me, zstd! ";
    }
    std::vector<char> compressed(ZSTD_compressBound(input.size()));
    const std::size_t compressed_size =
        ZSTD_compress(compressed.data(), compressed.size(), input.data(), input.size(), 3);
    ASSERT_EQ(ZSTD_isError(compressed_size), 0U);
    ASSERT_LT(compressed_size, input.size());

    std::string restored(input.size(), '\0');
    const std::size_t restored_size =
        ZSTD_decompress(restored.data(), restored.size(), compressed.data(), compressed_size);
    ASSERT_EQ(ZSTD_isError(restored_size), 0U);
    ASSERT_EQ(restored_size, input.size());
    EXPECT_EQ(restored, input);
}

}  // namespace deps_test
