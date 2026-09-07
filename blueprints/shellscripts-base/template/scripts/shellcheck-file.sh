#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  printf 'usage: %s FILE\n' "$0" >&2
  exit 1
fi

case "$1" in
  *.bats)
    shellcheck --shell=bats --severity=style --external-sources --source-path=SCRIPTDIR "$1"
    ;;
  *)
    shellcheck --severity=style --external-sources --source-path=SCRIPTDIR "$1"
    ;;
esac
