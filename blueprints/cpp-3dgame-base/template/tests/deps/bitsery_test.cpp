#include <bitsery/adapter/buffer.h>
#include <bitsery/bitsery.h>
#include <bitsery/traits/vector.h>
#include <gtest/gtest.h>

#include <cstdint>
#include <vector>

namespace deps_test {

struct Payload {
    std::uint32_t value{};
};

template <typename S>
void serialize(S& s, Payload& payload) {
    s.value4b(payload.value);
}

TEST(BitseryTest, RoundTripsStruct) {
    using Buffer = std::vector<std::uint8_t>;
    Buffer buffer;
    Payload original{1234567};
    const std::size_t written = bitsery::quickSerialization<bitsery::OutputBufferAdapter<Buffer>>(buffer, original);
    ASSERT_GT(written, 0U);

    Payload restored{};
    const auto state =
        bitsery::quickDeserialization<bitsery::InputBufferAdapter<Buffer>>({buffer.begin(), written}, restored);
    EXPECT_EQ(state.first, bitsery::ReaderError::NoError);
    EXPECT_TRUE(state.second);
    EXPECT_EQ(restored.value, original.value);
}

}  // namespace deps_test
