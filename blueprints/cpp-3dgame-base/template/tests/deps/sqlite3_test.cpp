#include <gtest/gtest.h>
#include <sqlite3.h>

namespace deps_test {

TEST(Sqlite3Test, OpensInMemoryDatabase) {
    sqlite3* db = nullptr;
    ASSERT_EQ(sqlite3_open(":memory:", &db), SQLITE_OK);
    ASSERT_NE(db, nullptr);
    EXPECT_EQ(sqlite3_exec(db, "CREATE TABLE t(x INTEGER); INSERT INTO t VALUES (1);", nullptr, nullptr, nullptr),
              SQLITE_OK);
    EXPECT_EQ(sqlite3_close(db), SQLITE_OK);
}

}  // namespace deps_test
