#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  printf 'Usage: %s NAME\n' "$0" >&2
  exit 1
fi

if [ -z "$1" ]; then
  printf 'error: NAME must not be empty\n' >&2
  exit 1
fi

printf 'Hello, %s!\n' "$1"
