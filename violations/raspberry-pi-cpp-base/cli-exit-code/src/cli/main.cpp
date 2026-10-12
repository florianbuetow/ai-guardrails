#include <iostream>

#include "test-raspberry-pi-cpp/application/application.hpp"

auto main(int, char*[]) -> int {
    return test_raspberry_pi_cpp::application::run(std::cout);
}
