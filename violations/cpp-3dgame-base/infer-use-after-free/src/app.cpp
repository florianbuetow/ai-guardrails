#include "test-cpp-3dgame-project/app.hpp"

#include <string>

namespace test_cpp_3dgame_project {

auto greet() -> std::string {
    // Infer detects USE_AFTER_FREE: accessing memory after delete
    auto* p = new std::string("Hello from test-cpp-3dgame-project!");
    std::string result = *p;
    delete p;
    return result + " length=" + std::to_string(p->length());
}

auto run() -> int {
    return 0;
}

}  // namespace test_cpp_3dgame_project
