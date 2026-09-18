#include "test-cpp-project/app.hpp"

#include <string>

namespace test_cpp_project {

auto greet() -> std::string {
    return "Hello from test-cpp-project!";
}

auto run() -> int {
    return 0;  // NOLINT
}

}  // namespace test_cpp_project
