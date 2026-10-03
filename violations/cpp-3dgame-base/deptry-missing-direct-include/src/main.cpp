#include <print>

#include "test-cpp-3dgame-project/app.hpp"

auto main() -> int {
    const std::string_view greeting = test_cpp_3dgame_project::greet();
    std::println("{}", greeting);
    return test_cpp_3dgame_project::run();
}
