#!/usr/bin/env bash
#
# List the files a recipe is about to act on, or fail loudly.
#
# Recipes must never pass an unexpanded shell glob to a tool. When
# `src/lib/*.S` matches nothing, bash hands the literal string through and
# clang reports:
#
#     clang: error: no such file or directory: 'src/lib/*.S'
#
# which says nothing about the real problem: the files are not there. This
# helper turns that into an explicit, named failure instead.

set -euo pipefail

if [ "$#" -ne 3 ]; then
    printf "usage: %s <directory> <name-pattern> <description>\n" "$0" >&2
    exit 1
fi

directory="$1"
pattern="$2"
description="$3"

if [ ! -d "$directory" ]; then
    printf "\033[31m✗ Error: %s directory is missing: %s\033[0m\n" "$description" "$directory" >&2
    printf "  The project is incomplete. Re-apply the template.\n" >&2
    exit 1
fi

matches="$(find "$directory" -type f -name "$pattern" | sort)"

if [ -z "$matches" ]; then
    printf "\033[31m✗ Error: no %s found in %s matching '%s'\033[0m\n" \
        "$description" "$directory" "$pattern" >&2
    printf "  The project is incomplete. Re-apply the template.\n" >&2
    exit 1
fi

printf "%s\n" "$matches"
