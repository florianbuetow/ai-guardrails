#!/usr/bin/env bash

set -euo pipefail

LANG_NAME="TypeScript"
TEMPLATE_DIR="react-vite-typescript-base"
PROJECT_NAME="test-react-project"
COPIER_DATA=(
    "project_name=test-react-project"
    "project_description=Test React application"
    "node_version=22"
    "author_name=Test Author"
    "author_email=test@example.com"
    "coverage_threshold=80"
)

check_prerequisites() {
    log_section "$LANG_NAME prerequisites"
    # Echo the generation parameters that runner.sh consumes from this config.
    printf "  template: %s, project: %s, copier entries: %d\n" \
        "$TEMPLATE_DIR" "$PROJECT_NAME" "${#COPIER_DATA[@]}"

    require_command copier "Install with: pip install copier"
    require_command just "Install from: https://github.com/casey/just#installation"
    require_command node "Install with: brew install node"
    require_command npm "npm ships with Node.js: https://nodejs.org/"
    require_command codespell "Install with: brew install codespell"
    require_command semgrep "Install with: brew install semgrep"
}
