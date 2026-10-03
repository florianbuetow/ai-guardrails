#include "test-cpp-3dgame-project/app.hpp"

#include <cstring>
#include <string_view>

namespace test_cpp_3dgame_project {

auto greet() -> std::string_view {
    const char* source = "Hello from test-cpp-3dgame-project!";
    char buf[10];
    strcpy(buf, source);
    return source;
}

auto run() -> int {
    return 0;
}

}  // namespace test_cpp_3dgame_project
