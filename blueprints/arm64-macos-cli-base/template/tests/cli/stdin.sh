#!/usr/bin/env bash
#
# '-' reads stdin, and a stream without a trailing newline is still a
# complete final value.

set -uo pipefail

if [ "$#" -ne 1 ]; then
    printf "usage: %s <binary>\n" "$0" >&2
    exit 1
fi
binary="$1"

failures=0

expect_output() {
    local expected="$1"
    local description="$2"
    local input="$3"
    local actual
    actual="$(printf '%s' "$input" | "$binary" sum -)"
    if [ "$actual" != "$expected" ]; then
        printf "    \033[31m✗ %s: expected '%s', got '%s'\033[0m\n" "$description" "$expected" "$actual" >&2
        failures=$((failures + 1))
    fi
}

expect_output "count=3 sum=6 max=3" "trailing newline" '1
2
3
'
expect_output "count=2 sum=9 max=5" "no trailing newline" '4
5'
expect_output "count=1 sum=42 max=42" "single value" '42
'
expect_output "count=3 sum=-6 max=-1" "all negative" '-1
-2
-3
'

if [ "$failures" -gt 0 ]; then
    printf "\033[31m✗ stdin: %d failure(s)\033[0m\n" "$failures" >&2
    exit 1
fi
