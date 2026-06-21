#include "test-cpp-3dgame-project/app.hpp"

#include <string>

namespace test_cpp_3dgame_project {

auto greet() -> std::string {
    int* p = nullptr;
    // Infer detects NULL_DEREFERENCE: dereferencing a null pointer
    int value = *p;
    return "Hello from test-cpp-3dgame-project! " + std::to_string(value);
}

auto run() -> int {
    return 0;
}

}  // namespace test_cpp_3dgame_project
