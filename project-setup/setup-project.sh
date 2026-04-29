#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
TEMPLATE_NAME=""
TARGET_DIR="."

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --template)
      TEMPLATE_NAME="$2"
      shift 2
      ;;
    --target)
      TARGET_DIR="$2"
      shift 2
      ;;
    *)
      echo -e "${RED}Error: Unknown option: $1${NC}"
      echo "Usage: $0 --template <template-name> [--target <directory>]"
      exit 1
      ;;
  esac
done

# Validate required parameters
if [ -z "$TEMPLATE_NAME" ]; then
  echo -e "${RED}Error: --template is required${NC}"
  echo "Usage: $0 --template <template-name> [--target <directory>]"
  exit 1
fi

# Determine paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_PATH="$REPO_ROOT/blueprints/$TEMPLATE_NAME"

# Check if template exists
if [ ! -d "$TEMPLATE_PATH" ]; then
  echo -e "${RED}Error: Template not found: $TEMPLATE_PATH${NC}"
  echo ""
  echo "Available templates:"
  for template_dir in "$REPO_ROOT/blueprints/"*; do
    if [ -d "$template_dir" ]; then
      echo "  - $(basename "$template_dir")"
    fi
  done
  echo ""
  exit 1
fi

# Check for copier
if ! command -v copier >/dev/null 2>&1; then
  echo -e "${RED}Error: copier is not installed${NC}"
  echo "Install with: pip install copier"
  exit 1
fi

# Create target directory if it doesn't exist
if [ "$TARGET_DIR" != "." ] && [ ! -d "$TARGET_DIR" ]; then
  mkdir -p "$TARGET_DIR"
fi

# Determine project name from target directory
# We need to cd into the target directory to get its absolute path and basename
ORIGINAL_DIR="$(pwd)"
cd "$TARGET_DIR"
TARGET_ABS_PATH="$(pwd)"
PROJECT_NAME=$(basename "$TARGET_ABS_PATH")
cd "$ORIGINAL_DIR"

# Convert hyphens to underscores for package name
PACKAGE_NAME=$(echo "$PROJECT_NAME" | tr '-' '_')

echo -e "${BLUE}=== Creating Project ===${NC}"
echo "Template: $TEMPLATE_NAME"
echo "Target: $TARGET_DIR"
echo "Project Name: $PROJECT_NAME"
echo "Package Name: $PACKAGE_NAME"
echo ""

# Run Copier
copier copy --trust --defaults \
  --data project_name="$PROJECT_NAME" \
  --data package_name="$PACKAGE_NAME" \
  --data module_path="$PROJECT_NAME" \
  --data project_description="A Python CLI application" \
  --data python_version="3.12" \
  --data author_name="" \
  --data author_email="" \
  --data coverage_threshold=80 \
  "$TEMPLATE_PATH" "$TARGET_DIR"

echo ""
echo -e "${GREEN}✓ Project created successfully!${NC}"
echo ""
