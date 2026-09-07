#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  printf 'usage: %s FILE\n' "$0" >&2
  exit 1
fi

case "$1" in
  *.bats)
    exit 0
    ;;
esac

first_line=
IFS= read -r first_line < "$1" || [ -n "$first_line" ]
case "$first_line" in
  '#!'*'/sh' | '#!'*'/sh '* | '#!'*'/env sh' | '#!'*'/env sh '* | \
    '#!'*'/dash' | '#!'*'/dash '* | '#!'*'/env dash' | '#!'*'/env dash '*)
    checkbashisms -p -f "$1"
    ;;
  '#!'*)
    exit 0
    ;;
  *)
    printf 'Missing shell shebang: %s\n' "$1" >&2
    exit 1
    ;;
esac
