#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  printf 'usage: %s CALLBACK\n' "$0" >&2
  exit 1
fi

callback=$1

find src scripts test spec \
  \( -type d \( -name .git -o -name .tools -o -name reports -o -name vendor -o -name vendored \) -prune \) -o \
  -type f -exec scripts/run-shell-file-check.sh "$callback" {} +
