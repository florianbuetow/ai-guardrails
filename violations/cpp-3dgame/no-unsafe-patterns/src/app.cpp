#include "test-cpp-3dgame-project/app.hpp"

#include <string>

namespace test_cpp_3dgame_project {

auto greet() -> std::string {
    return "Hello from test-cpp-3dgame-project!";
}

auto run() -> int {
    auto* ptr = new int(42);
    delete ptr;
    return 0;
}

}  // namespace test_cpp_3dgame_project
