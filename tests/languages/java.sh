#!/usr/bin/env bash
# shellcheck disable=SC2034 # Variables consumed by runner.sh which sources this file

set -euo pipefail

LANG_NAME="Java"
TEMPLATE_DIR="java-cli-base"
PROJECT_NAME="test-cli-project"
COPIER_DATA=(
    "project_name=test-cli-project"
    "group_id=com.example"
    "package_name=com.example.testcliproject"
    "package_path=com/example/testcliproject"
    "project_description=Test CLI application"
    "java_version=21"
    "author_name=Test Author"
    "author_email=test@example.com"
    "coverage_threshold=80"
)

check_prerequisites() {
    log_section "$LANG_NAME prerequisites"
    require_command copier "Install with: pip install copier"
    require_command just "Install from: https://github.com/casey/just#installation"

    if [ -d "/opt/homebrew/opt/openjdk@21/bin" ]; then
        export PATH="/opt/homebrew/opt/openjdk@21/bin:$PATH"
    fi

    require_command java "Install with: brew install openjdk@21"
    if ! java -version >/dev/null 2>&1; then
        log_fail "java runtime is not available (macOS stub detected or invalid installation)"
        printf "  Install with: brew install openjdk@21\n"
        exit 1
    fi
    log_pass "java runtime is usable"

    require_command codespell "Install with: brew install codespell"
    require_command semgrep "Install with: brew install semgrep"
    require_command infer "Install from: https://github.com/facebook/infer/releases"
}
