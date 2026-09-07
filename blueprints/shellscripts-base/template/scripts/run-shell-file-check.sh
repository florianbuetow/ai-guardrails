#!/bin/sh
set -eu

if [ "$#" -lt 2 ]; then
  printf 'usage: %s CALLBACK FILE...\n' "$0" >&2
  exit 1
fi

callback=$1
shift

for file in "$@"; do
  if scripts/is-shell-file.sh "$file"; then
    "$callback" "$file"
  fi
done
