#!/bin/sh
set -eu
if [ "$#" -lt 1 ]; then
    printf 'Usage: tools/bootstrap.sh <command> [arguments...]\n' >&2
    exit 2
fi
if [ "$1" = destroy ]; then
    rm -rf build
    printf "build/ removed\n"
    exit 0
fi
for tool in git just; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'Missing prerequisite: %s; install it before validation\n' "$tool" >&2
        exit 1
    fi
done
if [ "${CC+x}" = x ]; then
    if [ -z "$CC" ] || ! command -v "$CC" >/dev/null 2>&1; then
        printf 'CC must name one installed C compiler executable\n' >&2
        exit 1
    fi
    compiler=$CC
elif command -v cc >/dev/null 2>&1; then
    compiler=cc
elif command -v clang >/dev/null 2>&1; then
    compiler=clang
elif command -v gcc >/dev/null 2>&1; then
    compiler=gcc
else
    printf 'Install a C compiler providing cc, clang, or gcc\n' >&2
    exit 1
fi
export CC="$compiler"
if [ "$1" = check ]; then
    printf 'git: '; git --version
    printf 'just: '; just --version
    printf 'C compiler: '; "$compiler" --version
    printf 'platform: '; uname -sm
    exit 0
fi
if [ -L build ] || [ -L build/tools ] || [ -L build/tools/mmix-guard ]; then
    printf 'Refusing symlinked build outputs\n' >&2
    exit 1
fi
mkdir -p build/tools
"$compiler" -std=c11 -Wall -Wextra -Wpedantic -Werror tools/guard/*.c -o build/tools/mmix-guard
exec build/tools/mmix-guard "$@"
