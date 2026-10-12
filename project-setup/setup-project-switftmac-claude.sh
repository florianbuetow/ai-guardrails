#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -gt 1 ]; then
  printf "Usage: %s [target-directory]\n" "$0"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_SCRIPT="$SCRIPT_DIR/setup-project.sh"
TARGET_DIR="${1:-.}"

if [ ! -x "$SETUP_SCRIPT" ]; then
  printf "✗ Error: setup-project.sh not found or not executable: %s\n" "$SETUP_SCRIPT"
  exit 1
fi

"$SETUP_SCRIPT" --template switftmac --target "$TARGET_DIR"
