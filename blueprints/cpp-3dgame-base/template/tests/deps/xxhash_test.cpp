#include <gtest/gtest.h>
#include <xxhash.h>

#include <string>

namespace deps_test {

TEST(XxhashTest, HashesDeterministically) {
    const std::string data = "the quick brown fox";
    const XXH64_hash_t first = XXH64(data.data(), data.size(), 0);
    const XXH64_hash_t second = XXH64(data.data(), data.size(), 0);
    const XXH64_hash_t seeded = XXH64(data.data(), data.size(), 1);
    EXPECT_EQ(first, second);
    EXPECT_NE(first, seeded);
    EXPECT_EQ(XXH64(nullptr, 0, 0), 0xEF46DB3751D8E999ULL);
}

}  // namespace deps_test
