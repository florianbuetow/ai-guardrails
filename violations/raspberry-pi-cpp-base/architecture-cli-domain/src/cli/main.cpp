#include "test-raspberry-pi-cpp/domain/greeting.hpp"
#include <iostream>

#include "test-raspberry-pi-cpp/application/application.hpp"

auto main(int argc, char*[]) -> int {
    if (argc != 1) {
        std::cerr << "error: this command does not accept arguments\n";
        return 2;
    }

    const int result = test_raspberry_pi_cpp::application::run(std::cout);
    if (result != 0) {
        std::cerr << "error: failed to write output\n";
    }
    return result;
}
