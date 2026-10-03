#include "test-cpp-3dgame-project/app.hpp"

#include <string>
#include <string_view>

namespace test_cpp_3dgame_project {

auto greet() -> std::string_view {
    return "Hello from test-cpp-3dgame-project!";
}

auto run() -> int {
    // Infer detects USE_AFTER_FREE: accessing memory after delete
    auto* p = new std::string("Hello from test-cpp-3dgame-project!");
    std::string result = *p;
    delete p;
    return static_cast<int>(result.length() + p->length());
}

}  // namespace test_cpp_3dgame_project
