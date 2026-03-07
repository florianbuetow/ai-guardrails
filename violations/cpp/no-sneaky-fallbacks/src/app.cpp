#include "test-cpp-project/app.hpp"

#include <stdexcept>
#include <string>

namespace test_cpp_project {

auto greet() -> std::string {
    return "Hello from test-cpp-project!";
}

auto run() -> int {
    try {
        throw std::runtime_error("boom");
    } catch (...) {
    }
    return 0;
}

}  // namespace test_cpp_project
