#!/bin/sh
set -eu

find . \
  \( -type d \( -name .git -o -name .tools -o -name reports -o -name coverage -o -name report -o -name vendor -o -name vendored \) -prune \) -o \
  -type f -exec sh scripts/chmod-shell-file.sh {} +
