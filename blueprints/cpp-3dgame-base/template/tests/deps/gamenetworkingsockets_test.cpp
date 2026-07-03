#include <gtest/gtest.h>
#include <steam/steamnetworkingsockets.h>

namespace deps_test {

TEST(GameNetworkingSocketsTest, InitializesAndShutsDown) {
    SteamNetworkingErrMsg err_msg{};
    ASSERT_TRUE(GameNetworkingSockets_Init(nullptr, err_msg)) << err_msg;
    EXPECT_NE(SteamNetworkingSockets(), nullptr);
    GameNetworkingSockets_Kill();
}

}  // namespace deps_test
