#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  printf 'usage: %s FILE\n' "$0" >&2
  exit 1
fi

file=$1

case "$file" in
  *.bats)
    exit 0
    ;;
esac

first_line=
IFS= read -r first_line < "$file" || [ -n "$first_line" ]

case "$first_line" in
  '#!'*'/bash' | '#!'*'/bash '* | '#!'*' env bash' | '#!'*' env bash '*)
    bash -n "$file"
    exit 0
    ;;
  '#!'*'/dash' | '#!'*'/dash '* | '#!'*' env dash' | '#!'*' env dash '*)
    dash -n "$file"
    exit 0
    ;;
  '#!'*'/ksh' | '#!'*'/ksh '* | '#!'*' env ksh' | '#!'*' env ksh '*)
    ksh -n "$file"
    exit 0
    ;;
  '#!'*'/zsh' | '#!'*'/zsh '* | '#!'*' env zsh' | '#!'*' env zsh '*)
    zsh -n "$file"
    exit 0
    ;;
  '#!'*'/ash' | '#!'*'/ash '* | '#!'*' env ash' | '#!'*' env ash '* | \
    '#!'*' busybox ash' | '#!'*' busybox ash '*)
    if [ "$(uname -s)" != Linux ]; then
      printf 'BusyBox ash scripts require Linux validation: %s\n' "$file" >&2
      exit 1
    fi
    busybox ash -n "$file"
    exit 0
    ;;
esac

sh -n "$file"
bash -n "$file"
dash -n "$file"
ksh -n "$file"
zsh -n "$file"

case "$(uname -s)" in
  Darwin)
    :
    ;;
  Linux)
    busybox ash -n "$file"
    ;;
  *)
    printf 'unsupported operating system: %s\n' "$(uname -s)" >&2
    exit 1
    ;;
esac
