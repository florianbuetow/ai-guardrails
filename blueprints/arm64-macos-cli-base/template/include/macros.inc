// Project-wide constants shared by every translation unit.

#ifndef MACROS_INC
#define MACROS_INC

// Exit codes. The CLI contract is 0 success, 1 runtime failure,
// 2 usage error. Nothing else may reach _main's return value.
.set EXIT_OK,     0
.set EXIT_FAIL,   1
.set EXIT_USAGE,  2

// Standard file descriptors. Results go to stdout, diagnostics to stderr.
.set STDIN_FD,    0
.set STDOUT_FD,   1
.set STDERR_FD,   2

// Input buffer size. Input larger than this is a runtime failure rather
// than a silent truncation.
.set BUF_SIZE,    65536

// Parse outcomes returned in w1 by _parse_i64.
.set PARSE_OK,        0
.set PARSE_MALFORMED, 1
.set PARSE_OVERFLOW,  2

#endif
