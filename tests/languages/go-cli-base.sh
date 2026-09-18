#!/usr/bin/env bash
# shellcheck disable=SC2034 # Variables consumed by runner.sh which sources this file

set -euo pipefail

LANG_NAME="Go"
TEMPLATE_DIR="go-cli-base"
PROJECT_NAME="test-go-project"
COPIER_DATA=(
    "project_name=test-go-project"
    "module_path=github.com/test/test-go-project"
    "project_description=Test Go CLI application"
    "go_version=1.23"
    "author_name=Test Author"
    "author_email=test@example.com"
    "coverage_threshold=80"
)

check_prerequisites() {
    log_section "$LANG_NAME prerequisites"
    require_command copier "Install with: pip install copier"
    require_command just "Install from: https://github.com/casey/just#installation"
    require_command go "Install from: https://go.dev/dl/"
}
