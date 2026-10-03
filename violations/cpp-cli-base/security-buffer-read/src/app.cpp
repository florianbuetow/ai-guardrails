#include "test-cpp-project/app.hpp"

#include <cstring>
#include <string_view>

namespace test_cpp_project {

auto greet() -> std::string_view {
    return "Hello from test-cpp-project!";
}

auto run() -> int {
    const char* source = "Hello from test-cpp-project!";
    char buf[10];
    strcpy(buf, source);
    return buf[0];
}

}  // namespace test_cpp_project
