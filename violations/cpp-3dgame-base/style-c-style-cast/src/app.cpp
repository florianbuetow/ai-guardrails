#include "test-cpp-3dgame-project/app.hpp"

#include <string_view>

namespace test_cpp_3dgame_project {

auto greet() -> std::string_view {
    return "Hello from test-cpp-3dgame-project!";
}

auto run() -> int {
    double pi = 3.14159;
    int truncated = (int)pi;
    return truncated;
}

}  // namespace test_cpp_3dgame_project
