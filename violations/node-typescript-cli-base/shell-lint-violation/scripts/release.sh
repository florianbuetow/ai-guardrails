#!/usr/bin/env bash

set -euo pipefail

files=$(ls dist)
for file in $files; do
  printf "%s\n" $file
done
