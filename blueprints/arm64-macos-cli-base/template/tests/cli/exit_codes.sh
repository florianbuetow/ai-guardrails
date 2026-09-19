#!/usr/bin/env bash
#
# The CLI exit contract: 0 success, 1 runtime failure, 2 usage error.

set -uo pipefail

if [ "$#" -ne 1 ]; then
    printf "usage: %s <binary>\n" "$0" >&2
    exit 1
fi
binary="$1"

failures=0

expect_status() {
    local expected="$1"
    local description="$2"
    shift 2
    local actual=0
    "$@" >/dev/null 2>&1 || actual=$?
    if [ "$actual" != "$expected" ]; then
        printf "    \033[31m✗ %s: expected exit %s, got %s\033[0m\n" "$description" "$expected" "$actual" >&2
        failures=$((failures + 1))
    fi
}

expect_status 2 "no arguments" "$binary"
expect_status 2 "unknown subcommand" "$binary" mean -
expect_status 2 "too many operands" "$binary" sum - extra
expect_status 1 "unreadable file" "$binary" sum /dev/null/nope

workspace="$(mktemp -d)"
trap 'rm -rf "$workspace"' EXIT

printf '1\n2\n3\n' >"$workspace/good.txt"
printf '1\nnope\n' >"$workspace/malformed.txt"
printf '' >"$workspace/empty.txt"
printf '99999999999999999999\n' >"$workspace/huge.txt"

expect_status 0 "valid file" "$binary" sum "$workspace/good.txt"
expect_status 1 "malformed line" "$binary" sum "$workspace/malformed.txt"
expect_status 1 "empty input" "$binary" sum "$workspace/empty.txt"
expect_status 1 "value out of range" "$binary" sum "$workspace/huge.txt"

if [ "$failures" -gt 0 ]; then
    printf "\033[31m✗ exit_codes: %d failure(s)\033[0m\n" "$failures" >&2
    exit 1
fi
