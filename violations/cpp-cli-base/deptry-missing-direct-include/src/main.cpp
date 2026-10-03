#include <print>

#include "test-cpp-project/app.hpp"

auto main() -> int {
    const std::string_view greeting = test_cpp_project::greet();
    std::println("{}", greeting);
    return test_cpp_project::run();
}
