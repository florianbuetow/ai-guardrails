#!/usr/bin/env bash
#
# Suppresses a ShellCheck finding instead of quoting the expansion.

set -euo pipefail

target="$1"
# shellcheck disable=SC2086
printf '%s\n' $target
