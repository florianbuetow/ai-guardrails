#include <gtest/gtest.h>
#include <opus.h>

#include <string>

namespace deps_test {

TEST(OpusTest, CreatesEncoder) {
    const std::string version{opus_get_version_string()};
    EXPECT_NE(version.find("libopus"), std::string::npos);

    int error = OPUS_INTERNAL_ERROR;
    OpusEncoder* encoder = opus_encoder_create(48000, 2, OPUS_APPLICATION_AUDIO, &error);
    EXPECT_EQ(error, OPUS_OK);
    ASSERT_NE(encoder, nullptr);
    opus_encoder_destroy(encoder);
}

}  // namespace deps_test
