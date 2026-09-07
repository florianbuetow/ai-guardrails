#!/bin/sh
set -eu

if [ "$#" -lt 3 ]; then
  printf 'usage: %s MODE COUNT_FILE TEST_FILE...\n' "$0" >&2
  exit 1
fi

mode=$1
count_file=$2
shift 2

for test_file in "$@"; do
  if ! scripts/is-shell-file.sh "$test_file"; then
    continue
  fi

  case "$test_file" in
    *.bats)
      continue
      ;;
  esac

  printf 'x\n' >> "$count_file"

  report_failure() {
    status=$?
    if [ "$status" -ne 0 ]; then
      printf 'Test failed (%s): %s\n' "$status" "$test_file" >&2
    fi
  }
  trap report_failure EXIT

  case "$mode" in
    direct)
      TEST_SHELL='sh'
      export TEST_SHELL
      "$test_file"
      ;;
    matrix)
      TEST_SHELL='sh'
      export TEST_SHELL
      sh "$test_file"
      TEST_SHELL='bash'
      export TEST_SHELL
      bash "$test_file"
      TEST_SHELL='dash'
      export TEST_SHELL
      dash "$test_file"
      TEST_SHELL='ksh'
      export TEST_SHELL
      ksh "$test_file"
      TEST_SHELL='zsh'
      export TEST_SHELL
      zsh "$test_file"
      if [ "$(uname -s)" = Linux ]; then
        TEST_SHELL='busybox'
        export TEST_SHELL
        busybox ash "$test_file"
      fi
      ;;
    *)
      printf 'mode must be direct or matrix\n' >&2
      exit 1
      ;;
  esac
done
