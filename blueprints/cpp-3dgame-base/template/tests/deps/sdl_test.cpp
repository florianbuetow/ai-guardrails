#include <SDL3/SDL.h>
#include <gtest/gtest.h>

namespace deps_test {

TEST(SdlTest, InitializesEventsSubsystem) {
    EXPECT_GE(SDL_GetVersion(), SDL_VERSIONNUM(3, 0, 0));
    // The events subsystem needs no window server or GPU.
    ASSERT_TRUE(SDL_InitSubSystem(SDL_INIT_EVENTS)) << SDL_GetError();
    SDL_QuitSubSystem(SDL_INIT_EVENTS);
    SDL_Quit();
}

}  // namespace deps_test
