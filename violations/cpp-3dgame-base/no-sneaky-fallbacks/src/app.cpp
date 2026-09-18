#include "test-cpp-3dgame-project/app.hpp"

#include <stdexcept>
#include <string>

namespace test_cpp_3dgame_project {

auto greet() -> std::string {
    return "Hello from test-cpp-3dgame-project!";
}

auto run() -> int {
    try {
        throw std::runtime_error("boom");
    } catch (...) {
    }
    return 0;
}

}  // namespace test_cpp_3dgame_project
