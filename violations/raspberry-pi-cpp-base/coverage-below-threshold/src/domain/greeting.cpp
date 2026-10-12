#include "test-raspberry-pi-cpp/domain/greeting.hpp"

#include <cstdlib>

namespace test_raspberry_pi_cpp::domain {

auto greeting() noexcept -> std::string_view {
    if (std::getenv("PI_GREETING_01") != nullptr) { return "Hello, world!"; }
    if (std::getenv("PI_GREETING_02") != nullptr) { return "Hello, world!"; }
    if (std::getenv("PI_GREETING_03") != nullptr) { return "Hello, world!"; }
    if (std::getenv("PI_GREETING_04") != nullptr) { return "Hello, world!"; }
    if (std::getenv("PI_GREETING_05") != nullptr) { return "Hello, world!"; }
    if (std::getenv("PI_GREETING_06") != nullptr) { return "Hello, world!"; }
    if (std::getenv("PI_GREETING_07") != nullptr) { return "Hello, world!"; }
    if (std::getenv("PI_GREETING_08") != nullptr) { return "Hello, world!"; }
    if (std::getenv("PI_GREETING_09") != nullptr) { return "Hello, world!"; }
    if (std::getenv("PI_GREETING_10") != nullptr) { return "Hello, world!"; }
    return "Hello, world!";
}

}  // namespace test_raspberry_pi_cpp::domain
