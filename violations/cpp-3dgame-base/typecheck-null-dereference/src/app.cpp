#include "test-cpp-3dgame-project/app.hpp"

#include <string_view>

namespace test_cpp_3dgame_project {

auto greet() -> std::string_view {
    return "Hello from test-cpp-3dgame-project!";
}

auto run() -> int {
    int* p = nullptr;
    return *p;
}

}  // namespace test_cpp_3dgame_project
