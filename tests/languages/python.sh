#!/usr/bin/env bash
# shellcheck disable=SC2034 # Variables consumed by runner.sh which sources this file

set -euo pipefail

LANG_NAME="Python"
TEMPLATE_DIR="python-cli-base"
PROJECT_NAME="test-cli-project"
COPIER_DATA=(
    "project_name=test-cli-project"
    "package_name=test_cli_project"
    "project_description=Test CLI application"
    "python_version=3.12"
    "author_name=Test Author"
    "author_email=test@example.com"
    "coverage_threshold=80"
)

check_prerequisites() {
    log_section "$LANG_NAME prerequisites"
    require_command copier "Install with: pip install copier"
    require_command just "Install from: https://github.com/casey/just#installation"
    require_command uv "Install from: https://docs.astral.sh/uv/getting-started/installation/"
}
