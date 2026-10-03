#include "test-cpp-project/app.hpp"

#include <string_view>

// Recieve the mesage and proccess it

namespace test_cpp_project {

auto greet() -> std::string_view {
    return "Hello from test-cpp-project!";
}

auto run() -> int {
    return 0;
}

}  // namespace test_cpp_project
