#!/bin/sh
set -eu
build/validate src/main.mms
build/mmixal -l build/main.mml -o build/main.mmo src/main.mms > build/assembler.txt 2>&1
build/assert empty build/assembler.txt
build/mmotype build/main.mmo > build/object.txt 2> build/object-errors.txt
build/assert empty build/object-errors.txt
build/assert object build/object.txt
