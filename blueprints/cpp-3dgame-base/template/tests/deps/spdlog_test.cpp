#include <gtest/gtest.h>
#include <spdlog/sinks/ostream_sink.h>
#include <spdlog/spdlog.h>

#include <memory>
#include <sstream>
#include <string>

namespace deps_test {

TEST(SpdlogTest, WritesToOstreamSink) {
    std::ostringstream stream;
    auto sink = std::make_shared<spdlog::sinks::ostream_sink_mt>(stream);
    spdlog::logger logger("smoke", sink);
    logger.info("hello spdlog");
    EXPECT_NE(stream.str().find("hello spdlog"), std::string::npos);
}

}  // namespace deps_test
