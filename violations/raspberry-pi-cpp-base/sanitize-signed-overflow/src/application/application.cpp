#include "test-raspberry-pi-cpp/application/application.hpp"

#include <limits>
#include <ostream>

#include "test-raspberry-pi-cpp/domain/greeting.hpp"

namespace test_raspberry_pi_cpp::application {

auto run(std::ostream& output) -> int {
    volatile int maximum = std::numeric_limits<int>::max();
    volatile int overflow = maximum + 1;
    output << domain::greeting() << '\n';
    output.flush();
    return output && overflow != 0 ? 0 : 1;
}

}  // namespace test_raspberry_pi_cpp::application
