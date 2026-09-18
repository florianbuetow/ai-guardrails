#!/usr/bin/env bats
@test "checks the greeting" {
  run sh src/main.sh World
  [ "$status" -eq 0 ]
  [ "$output" = "incorrect greeting" ]
}
