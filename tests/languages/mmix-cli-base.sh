#!/usr/bin/env bash

set -euo pipefail

LANG_NAME="MMIX Assembly CLI"
TEMPLATE_DIR="mmix-cli-base"
PROJECT_NAME="test-mmix-cli"
export NO_GIT_MUTATIONS=true
COPIER_DATA=(
    "project_name=test-mmix-cli"
    "project_description=Test MMIX assembly CLI"
    "author_name=Test Author"
    "author_email=test@example.com"
)

check_prerequisites() {
    log_section "$LANG_NAME prerequisites"
    printf "  template: %s, project: %s, copier entries: %d\n" \
        "$TEMPLATE_DIR" "$PROJECT_NAME" "${#COPIER_DATA[@]}"

    require_command copier "Install with: pip install copier"
    require_command just "Install from: https://github.com/casey/just#installation"
    require_command git "Install from: https://git-scm.com/downloads"

    case "$(uname -s)" in
        MINGW*|MSYS*|CYGWIN*)
            require_command clang "Install Clang and make it available in Git Bash"
            ;;
        *)
            require_command cc "Install a C compiler that provides cc"
            ;;
    esac
}

post_baseline_tests() {
    local project_dir="$1"
    local output

    log_section "$LANG_NAME runnable application"
    if ! output="$(cd "$project_dir" && just run 2>&1)"; then
        log_fail "just run failed"
        printf "%s\n" "$output"
        return 1
    fi
    if ! printf "%s\n" "$output" | grep -F "Hello, MMIX!" >/dev/null; then
        log_fail "just run did not execute the generated MMIX program"
        printf "%s\n" "$output"
        return 1
    fi
    log_pass "just run assembled and executed the generated MMIX program"
}
