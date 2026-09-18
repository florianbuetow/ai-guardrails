#include "test-cpp-project/app.hpp"

#include <string>

namespace test_cpp_project {

auto greet() -> std::string {
    double pi = 3.14159;
    int truncated = (int)pi;
    return "Hello from test-cpp-project! " + std::to_string(truncated);
}

auto run() -> int {
    return 0;
}

}  // namespace test_cpp_project
