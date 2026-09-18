#include "test-cpp-3dgame-project/app.hpp"

#include <string>

namespace test_cpp_3dgame_project {

auto greet() -> std::string {
    return "Hello from test-cpp-3dgame-project!";
}

auto run() -> int {
    return 0;  // NOLINT
}

}  // namespace test_cpp_3dgame_project
