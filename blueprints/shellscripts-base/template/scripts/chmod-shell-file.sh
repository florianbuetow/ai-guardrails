#!/bin/sh
set -eu

if [ "$#" -lt 1 ]; then
  printf 'usage: %s FILE...\n' "$0" >&2
  exit 1
fi

for file in "$@"; do
  if sh scripts/is-shell-file.sh "$file"; then
    chmod +x "$file"
  fi
done
