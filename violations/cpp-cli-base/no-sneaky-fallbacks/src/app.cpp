#include "test-cpp-project/app.hpp"

#include <stdexcept>
#include <string_view>

namespace test_cpp_project {

auto greet() -> std::string_view {
    return "Hello from test-cpp-project!";
}

auto run() -> int {
    try {
        throw std::runtime_error("boom");
    } catch (...) {}
    return 0;
}

}  // namespace test_cpp_project
