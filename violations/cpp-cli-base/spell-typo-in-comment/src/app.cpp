#include "test-cpp-project/app.hpp"

#include <string>

// Recieve the mesage and proccess it

namespace test_cpp_project {

auto greet() -> std::string {
    return "Hello from test-cpp-project!";
}

auto run() -> int {
    return 0;
}

}  // namespace test_cpp_project
