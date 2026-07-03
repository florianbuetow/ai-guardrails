#include <Jolt/Jolt.h>

#include <Jolt/Core/Factory.h>
#include <Jolt/RegisterTypes.h>
#include <gtest/gtest.h>

namespace deps_test {

TEST(JoltPhysicsTest, RegistersTypeSystem) {
    JPH::RegisterDefaultAllocator();
    // Jolt's API prescribes `new JPH::Factory`; static storage avoids raw new
    // (banned by the template guardrails) and outlives type registration.
    static JPH::Factory factory;
    JPH::Factory::sInstance = &factory;
    JPH::RegisterTypes();
    EXPECT_NE(JPH::Factory::sInstance, nullptr);
    JPH::UnregisterTypes();
    JPH::Factory::sInstance = nullptr;
}

}  // namespace deps_test
