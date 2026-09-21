#!/bin/sh
set -eu
compiler=$1
mkdir -p build
"$compiler" -std=gnu89 -O2 vendor/mmixware/abstime.c -o build/abstime
build/abstime > build/abstime.h
"$compiler" -std=c99 -Wall -Wextra -Wpedantic -Werror tools/validate.c -o build/validate
"$compiler" -std=c99 -Wall -Wextra -Wpedantic -Werror tools/assert.c -o build/assert
"$compiler" -std=gnu89 -O2 -Ibuild -Ivendor/mmixware vendor/mmixware/mmixal.c vendor/mmixware/mmix-arith.c -o build/mmixal
"$compiler" -std=gnu89 -O2 -Ibuild -Ivendor/mmixware vendor/mmixware/mmix-sim.c vendor/mmixware/mmix-arith.c vendor/mmixware/mmix-io.c -o build/mmix
"$compiler" -std=gnu89 -O2 -Ibuild -Ivendor/mmixware vendor/mmixware/mmotype.c -o build/mmotype
