#!/bin/sh
set -eu
for tool in "$1" just git; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'Missing required prerequisite: %s\n' "$tool" >&2
        exit 1
    fi
done
for source in abstime.c mmixal.c mmix-sim.c mmix-arith.c mmix-io.c mmotype.c; do
    if [ ! -f "vendor/mmixware/$source" ]; then
        printf 'Missing vendored source: %s\n' "$source" >&2
        exit 1
    fi
done
