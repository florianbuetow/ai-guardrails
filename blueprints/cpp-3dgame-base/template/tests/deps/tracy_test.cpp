#include <gtest/gtest.h>

#include <tracy/Tracy.hpp>

namespace deps_test {

namespace {

int InstrumentedWork() {
    ZoneScopedN("deps_test::InstrumentedWork");
    return 21 + 21;
}

}  // namespace

TEST(TracyTest, InstrumentsZoneWithoutServer) {
    // on_demand=True: no profiler server is contacted unless one connects.
    EXPECT_EQ(InstrumentedWork(), 42);
}

}  // namespace deps_test
