#!/bin/sh
set -eu
build/validate --self-test
build/mmix build/main.mmo > build/stdout.txt 2> build/stderr.txt
build/assert equal tests/stdout.txt build/stdout.txt
build/assert empty build/stderr.txt
build/mmix -P build/main.mmo > build/profile.txt 2> build/profile-errors.txt
build/assert empty build/profile-errors.txt
build/assert coverage build/object.txt build/main.mml build/profile.txt
build/mmix -I build/main.mmo < tests/state.txt > build/state.txt 2> build/state-errors.txt
build/assert empty build/state-errors.txt
build/assert contains build/state.txt 'g[255]=#0'
build/assert contains build/state.txt 'M8[#2000000000000000]=#48656c6c6f2c204d'
sh scripts/test-guards.sh
