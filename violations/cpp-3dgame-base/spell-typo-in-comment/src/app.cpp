#include "test-cpp-3dgame-project/app.hpp"

#include <string_view>

// Recieve the mesage and proccess it

namespace test_cpp_3dgame_project {

auto greet() -> std::string_view {
    return "Hello from test-cpp-3dgame-project!";
}

auto run() -> int {
    return 0;
}

}  // namespace test_cpp_3dgame_project
