#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  printf 'usage: %s FILE\n' "$0" >&2
  exit 1
fi

case "$SHFMT_MODE" in
  check)
    shfmt -d -i 2 -ci -sr "$1"
    ;;
  write)
    shfmt -w -i 2 -ci -sr "$1"
    ;;
  *)
    printf 'SHFMT_MODE must be check or write\n' >&2
    exit 1
    ;;
esac
