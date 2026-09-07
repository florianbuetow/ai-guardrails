#!/usr/bin/env bats

@test "greets a name with whitespace" {
  run sh src/main.sh 'Shell World'
  [ "$status" -eq 0 ]
  [ "$output" = 'Hello, Shell World!' ]
}

@test "rejects a missing name" {
  run sh src/main.sh
  [ "$status" -eq 1 ]
  [[ "$output" == Usage:* ]]
}

@test "rejects an empty name" {
  run sh src/main.sh ''
  [ "$status" -eq 1 ]
  [ "$output" = 'error: NAME must not be empty' ]
}
