#!/usr/bin/env bash
#
# Print the Homebrew LLVM bin directory.
#
# Homebrew LLVM is keg-only, so FileCheck, llvm-objdump, llvm-readobj and
# llvm-mca are never on PATH. Xcode ships some of these under different
# versions and omits others entirely, so this project resolves one
# toolchain or fails — it never falls back.

set -euo pipefail

if ! command -v brew >/dev/null 2>&1; then
    printf "\033[31m✗ Error: Homebrew is not installed\033[0m\n" >&2
    printf "  LLVM tools (FileCheck, llvm-objdump, llvm-readobj, llvm-mca) come from Homebrew LLVM.\n" >&2
    printf "  Install Homebrew: https://brew.sh\n" >&2
    exit 1
fi

if ! prefix="$(brew --prefix llvm 2>/dev/null)"; then
    printf "\033[31m✗ Error: Homebrew LLVM is not installed\033[0m\n" >&2
    printf "  Install with: brew install llvm\n" >&2
    exit 1
fi

if [ -z "$prefix" ] || [ ! -d "$prefix/bin" ]; then
    printf "\033[31m✗ Error: Homebrew LLVM prefix has no bin directory: %s\033[0m\n" "$prefix" >&2
    printf "  Reinstall with: brew reinstall llvm\n" >&2
    exit 1
fi

printf "%s/bin\n" "$prefix"
