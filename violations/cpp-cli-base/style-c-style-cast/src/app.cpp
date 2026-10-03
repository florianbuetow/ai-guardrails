#include "test-cpp-project/app.hpp"

#include <string_view>

namespace test_cpp_project {

auto greet() -> std::string_view {
    return "Hello from test-cpp-project!";
}

auto run() -> int {
    double pi = 3.14159;
    return (int)pi;
}

}  // namespace test_cpp_project
