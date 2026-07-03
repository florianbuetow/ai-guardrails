#include <gtest/gtest.h>

#include <pqxx/pqxx>
#include <stdexcept>

namespace deps_test {

TEST(LibpqxxTest, RejectsUnreachableServer) {
    // No PostgreSQL server runs in CI; a refused connection proves the client
    // library is linked and functional.
    EXPECT_THROW({ pqxx::connection conn{"host=127.0.0.1 port=1 dbname=smoke connect_timeout=1"}; }, std::exception);
}

}  // namespace deps_test
