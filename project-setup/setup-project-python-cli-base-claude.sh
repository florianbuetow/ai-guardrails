#!/bin/bash

# Check if target directory parameter is provided
if [ -z "$1" ]; then
  echo "Error: Target directory parameter required"
  echo "Usage: $0 <target-directory>"
  exit 1
fi

TARGET_DIR="$1"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_SCRIPT="$SCRIPT_DIR/setup-project.sh"

# Check if setup-project.sh exists
if [ ! -f "$SETUP_SCRIPT" ]; then
  echo "✗ Error: setup-project.sh not found: $SETUP_SCRIPT"
  exit 1
fi

# Execute setup-project.sh with python-cli-base template
"$SETUP_SCRIPT" --template python-cli-base --target "$TARGET_DIR"

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
  echo ""
  echo "✓ Project setup complete!"
  echo ""
else
  echo ""
  echo "✗ Project setup failed"
  echo ""
  exit $EXIT_CODE
fi
