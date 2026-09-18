#include "test-cpp-3dgame-project/app.hpp"

#include <string>

namespace test_cpp_3dgame_project {

auto greet() -> std::string {
    double pi = 3.14159;
    int truncated = (int)pi;
    return "Hello from test-cpp-3dgame-project! " + std::to_string(truncated);
}

auto run() -> int {
    return 0;
}

}  // namespace test_cpp_3dgame_project
