#!/bin/sh
set -eu

shellspec --fail-no-examples -s sh spec
shellspec --fail-no-examples -s bash spec
shellspec --fail-no-examples -s dash spec
shellspec --fail-no-examples -s ksh spec
shellspec --fail-no-examples -s zsh spec

if [ "$(uname -s)" = Linux ]; then
  wrapper_directory=$(mktemp -d)
  trap 'rm -rf "$wrapper_directory"' EXIT HUP INT TERM
  wrapper=$wrapper_directory/ash
  ln -s "$(command -v busybox)" "$wrapper"
  shellspec --fail-no-examples -s "$wrapper" spec
fi
