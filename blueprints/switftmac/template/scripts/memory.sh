#!/bin/bash
set -euo pipefail
if [ "$#" -ne 1 ]; then
    printf 'A running application PID is required\n' >&2
    exit 1
fi
case "$1" in '' | *[!0-9]*)
    printf 'PID must be a positive integer\n' >&2
    exit 1
    ;;
esac
[ "$1" -gt 0 ]
bash scripts/check-host.sh
mkdir -p build/reports
vmmap "$1" >"build/reports/vmmap-$1.txt"
leaks "$1" >"build/reports/leaks-$1.txt"
cat "build/reports/leaks-$1.txt"
