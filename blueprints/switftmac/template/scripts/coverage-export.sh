#!/bin/bash
set -euo pipefail
if [ "$#" -ne 2 ]; then
    printf 'Usage: coverage-export.sh PROFILE.profdata INSTRUMENTED_BINARY\n' >&2
    exit 1
fi
[ -s "$1" ] && [ -f "$2" ]
bash scripts/check-host.sh
mkdir -p build/reports
xcrun llvm-profdata show "$1" >build/reports/profile-summary.txt
xcrun llvm-cov export "$2" -instr-profile="$1" >build/reports/llvm-coverage.json
printf '\033[32mLLVM coverage exported to build/reports/llvm-coverage.json\033[0m\n'
