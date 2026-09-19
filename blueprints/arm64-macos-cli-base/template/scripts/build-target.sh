#!/usr/bin/env bash
#
# Print the Clang target triple every build step uses.
#
# The target lives in config/target.txt rather than inline in the justfile
# so that one file is the single build input, and so that changing it is a
# visible, reviewable diff. scripts/verify-binary.sh pins the expected value
# and cross-checks the linked binary against it.

set -euo pipefail

target_file="config/target.txt"

if [ ! -f "$target_file" ]; then
    printf "\033[31m✗ Error: %s is missing\033[0m\n" "$target_file" >&2
    exit 1
fi

target="$(grep -v '^[[:space:]]*#' "$target_file" | grep -v '^[[:space:]]*$' | head -1)"

if [ -z "$target" ]; then
    printf "\033[31m✗ Error: %s declares no target triple\033[0m\n" "$target_file" >&2
    exit 1
fi

printf "%s\n" "$target"
