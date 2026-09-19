#!/usr/bin/env bash
#
# Results go to stdout, diagnostics go to stderr, and neither leaks into
# the other.

set -uo pipefail

if [ "$#" -ne 1 ]; then
    printf "usage: %s <binary>\n" "$0" >&2
    exit 1
fi
binary="$1"

failures=0

workspace="$(mktemp -d)"
trap 'rm -rf "$workspace"' EXIT

printf '5\n-7\n12\n0\n' >"$workspace/values.txt"

stdout_text="$("$binary" sum "$workspace/values.txt" 2>"$workspace/stderr.txt")"
if [ "$stdout_text" != "count=4 sum=10 max=12" ]; then
    printf "    \033[31m✗ unexpected stdout: %s\033[0m\n" "$stdout_text" >&2
    failures=$((failures + 1))
fi
if [ -s "$workspace/stderr.txt" ]; then
    printf "    \033[31m✗ success path wrote to stderr\033[0m\n" >&2
    failures=$((failures + 1))
fi

# These scripts deliberately do not set -e: a non-zero exit is the thing
# under test, so it must be observed rather than abort the script.
stdout_text="$("$binary" 2>"$workspace/usage.txt")"
if [ -n "$stdout_text" ]; then
    printf "    \033[31m✗ usage error wrote to stdout\033[0m\n" >&2
    failures=$((failures + 1))
fi
if ! grep -q "usage:" "$workspace/usage.txt"; then
    printf "    \033[31m✗ usage text missing from stderr\033[0m\n" >&2
    failures=$((failures + 1))
fi

if [ "$failures" -gt 0 ]; then
    printf "\033[31m✗ output: %d failure(s)\033[0m\n" "$failures" >&2
    exit 1
fi
