#!/bin/bash
# Install the language-independent AI review commands into the current project.

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$#" -ne 0 ]; then
  printf '\033[31m✗ Error: %s takes no arguments; it installs AI review support in the current directory\033[0m\n' "$SCRIPT_NAME"
  printf 'Usage: %s\n' "$SCRIPT_NAME"
  exit 1
fi

if ! command -v uv >/dev/null 2>&1; then
  printf '\033[31m✗ Error: uv is required to run the AI review installer\033[0m\n'
  exit 1
fi

exec uv run --no-project python "$SCRIPT_DIR/install_ai_review.py"
