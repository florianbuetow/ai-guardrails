#include "test-raspberry-pi-cpp/domain/greeting.hpp"

#include "test-raspberry-pi-cpp/application/application.hpp"

namespace test_raspberry_pi_cpp::domain {

auto greeting() noexcept -> std::string_view {
    return "Hello, world!";
}

}  // namespace test_raspberry_pi_cpp::domain
