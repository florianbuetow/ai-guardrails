#!/usr/bin/env bash

set -euo pipefail

LANG_NAME="Shell scripts"
TEMPLATE_DIR="shellscripts-base"
PROJECT_NAME="test-shellscripts-project"
COPIER_DATA=(
    "project_name=test-shellscripts-project"
    "project_description=Test portable shell script project"
    "author_name=Test Author"
    "author_email=test@example.com"
)

check_prerequisites() {
    local bash_major

    log_section "$LANG_NAME prerequisites"
    printf "  template: %s, project: %s, copier entries: %d\n" \
        "$TEMPLATE_DIR" "$PROJECT_NAME" "${#COPIER_DATA[@]}"

    if [ "$(uname -s)" = "Darwin" ]; then
        if [ -x "/opt/homebrew/bin/bash" ]; then
            export PATH="/opt/homebrew/bin:$PATH"
        elif [ -x "/usr/local/bin/bash" ]; then
            export PATH="/usr/local/bin:$PATH"
        fi
    fi

    require_command copier "Install with: pip install copier"
    require_command just "Install from: https://github.com/casey/just#installation"
    require_command shellcheck "Install with: brew install shellcheck"
    require_command shfmt "Install with: brew install shfmt"
    require_command checkbashisms "Install with: brew install checkbashisms"
    require_command semgrep "Install with: brew install semgrep"
    require_command codespell "Install with: brew install codespell"
    require_command bats "Install with: brew install bats-core"
    require_command shellspec "Install with: brew install shellspec"
    require_command kcov "Install from: https://github.com/SimonKagstrom/kcov/blob/master/INSTALL.md"
    require_command bash "Install with: brew install bash"
    bash_major="$(bash -c 'printf "%s\n" "${BASH_VERSION%%.*}"')"
    case "$bash_major" in
        ''|*[!0-9]*)
            log_fail "unable to determine a numeric Bash version"
            exit 1
            ;;
    esac
    if [ "$bash_major" -lt 4 ]; then
        log_fail "Bash 4+ is required, found Bash $bash_major"
        printf "  Install with: brew install bash, then put Homebrew Bash first in PATH\n"
        exit 1
    fi
    log_pass "Bash 4+ is installed"
    require_command dash "Install with: brew install dash"
    require_command ksh "Install with: brew install ksh93"
    require_command zsh "Install with: brew install zsh"

    if [ "$(uname -s)" = "Linux" ]; then
        require_command busybox "Install with your Linux package manager"
    fi
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
    if ! printf "%s\n" "$output" | grep -F "Hello, World!" >/dev/null; then
        log_fail "just run did not execute the generated shell script"
        printf "%s\n" "$output"
        return 1
    fi
    log_pass "just run executed the generated shell script"
}
