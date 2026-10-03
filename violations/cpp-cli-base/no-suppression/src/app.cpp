#include "test-cpp-project/app.hpp"

#include <string_view>

namespace test_cpp_project {

auto greet() -> std::string_view {
    return "Hello from test-cpp-project!";
}

auto run() -> int {
    return 0;  // NOLINT
}

}  // namespace test_cpp_project
