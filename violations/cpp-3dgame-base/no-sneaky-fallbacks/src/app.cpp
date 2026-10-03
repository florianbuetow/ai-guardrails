#include "test-cpp-3dgame-project/app.hpp"

#include <stdexcept>
#include <string_view>

namespace test_cpp_3dgame_project {

auto greet() -> std::string_view {
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
