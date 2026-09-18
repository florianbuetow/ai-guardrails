#!/bin/bash

set -e

if [ "$#" -ne 1 ]; then
  printf "Error: exactly one target directory is required\n"
  printf "Usage: %s <target-directory>\n" "$0"
  exit 1
fi

TARGET_DIR="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_SCRIPT="$SCRIPT_DIR/setup-project.sh"

if [ ! -f "$SETUP_SCRIPT" ]; then
  printf "✗ Error: setup-project.sh not found: %s\n" "$SETUP_SCRIPT"
  exit 1
fi

"$SETUP_SCRIPT" --template mcp-server-typescript-base --target "$TARGET_DIR"
printf "\n✓ TypeScript MCP server setup complete!\n\n"
