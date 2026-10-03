#include "test-cpp-project/app.hpp"

#include <string>
#include <string_view>

namespace test_cpp_project {

auto greet() -> std::string_view {
    return "Hello from test-cpp-project!";
}

auto run() -> int {
    // Infer detects USE_AFTER_FREE: accessing memory after delete
    auto* p = new std::string("Hello from test-cpp-project!");
    delete p;
    return static_cast<int>(p->length());
}

}  // namespace test_cpp_project
