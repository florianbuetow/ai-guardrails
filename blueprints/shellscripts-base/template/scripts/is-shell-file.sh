#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  printf 'usage: %s FILE\n' "$0" >&2
  exit 1
fi

file=$1
name=${file##*/}

case "$name" in
  *.sh | *.bash | *.bats)
    exit 0
    ;;
esac

first_line=
IFS= read -r first_line < "$file" || [ -n "$first_line" ]

case "$first_line" in
  '#!'*'/sh' | '#!'*'/sh '* | '#!'*' env sh' | '#!'*' env sh '* | \
    '#!'*'/bash' | '#!'*'/bash '* | '#!'*' env bash' | '#!'*' env bash '* | \
    '#!'*'/dash' | '#!'*'/dash '* | '#!'*' env dash' | '#!'*' env dash '* | \
    '#!'*'/ksh' | '#!'*'/ksh '* | '#!'*' env ksh' | '#!'*' env ksh '* | \
    '#!'*'/zsh' | '#!'*'/zsh '* | '#!'*' env zsh' | '#!'*' env zsh '* | \
    '#!'*'/ash' | '#!'*'/ash '* | '#!'*' env ash' | '#!'*' env ash '* | \
    '#!'*' busybox ash' | '#!'*' busybox ash '*)
    exit 0
    ;;
esac

exit 1
