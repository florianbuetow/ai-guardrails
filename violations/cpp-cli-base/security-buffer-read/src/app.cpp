#include "test-cpp-project/app.hpp"

#include <cstring>
#include <string>

namespace test_cpp_project {

auto greet() -> std::string {
    const char* source = "Hello from test-cpp-project!";
    char buf[10];
    strcpy(buf, source);
    return std::string(buf);
}

auto run() -> int {
    return 0;
}

}  // namespace test_cpp_project
