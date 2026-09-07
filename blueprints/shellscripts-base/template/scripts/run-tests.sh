#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  printf 'usage: %s direct|matrix\n' "$0" >&2
  exit 1
fi

mode=$1
case "$mode" in
  direct | matrix)
    :
    ;;
  *)
    printf 'mode must be direct or matrix\n' >&2
    exit 1
    ;;
esac

count_file=$(mktemp)
trap 'rm -f "$count_file"' EXIT HUP INT TERM

find test -type f -name 'test*' -exec scripts/run-test-file.sh "$mode" "$count_file" {} +

if [ ! -s "$count_file" ]; then
  printf 'No executable shell tests matching test/test* were found.\n' >&2
  exit 1
fi
