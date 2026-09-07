#!/bin/sh
set -eu

# The runner selects the interpreter explicitly for every test invocation.
if [ "${TEST_SHELL+x}" != x ]; then
  printf 'error: TEST_SHELL is required; run just test\n' >&2
  exit 1
fi
test_shell=$TEST_SHELL
if [ -z "$test_shell" ]; then
  printf 'error: TEST_SHELL must not be empty\n' >&2
  exit 1
fi

run_main() {
  if [ "$test_shell" = busybox ]; then
    busybox ash src/main.sh "$@"
  else
    "$test_shell" src/main.sh "$@"
  fi
}

output=$(run_main 'Shell World')
[ "$output" = 'Hello, Shell World!' ]
output=$(run_main '-name * [with spaces]')
[ "$output" = 'Hello, -name * [with spaces]!' ]

if run_main; then
  printf 'error: missing name was accepted\n' >&2
  exit 1
fi
if run_main ''; then
  printf 'error: empty name was accepted\n' >&2
  exit 1
fi
if run_main one two; then
  printf 'error: extra arguments were accepted\n' >&2
  exit 1
fi
