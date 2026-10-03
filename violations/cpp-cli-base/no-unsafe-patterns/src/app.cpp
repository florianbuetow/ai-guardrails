#include "test-cpp-project/app.hpp"

#include <string_view>

namespace test_cpp_project {

auto greet() -> std::string_view {
    return "Hello from test-cpp-project!";
}

auto run() -> int {
    auto* ptr = new int(42);
    delete ptr;
    return 0;
}

}  // namespace test_cpp_project
