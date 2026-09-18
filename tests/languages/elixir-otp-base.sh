#!/usr/bin/env bash
# shellcheck disable=SC2034 # Variables consumed by runner.sh which sources this file

set -euo pipefail

LANG_NAME="Elixir"
TEMPLATE_DIR="elixir-otp-base"
PROJECT_NAME="test-otp-app"
COPIER_DATA=(
    "project_name=test-otp-app"
    "app_name=test_otp_app"
    "module_name=TestOtpApp"
    "project_description=Test OTP application"
    "elixir_version=1.17"
    "author_name=Test Author"
    "coverage_threshold=80"
)

check_prerequisites() {
    log_section "$LANG_NAME prerequisites"
    require_command copier "Install with: pip install copier"
    require_command just "Install from: https://github.com/casey/just#installation"
    require_command elixir "Install from: https://elixir-lang.org/install.html"
    require_command mix "Installed with Elixir"
}

validate_baseline_output() {
    local baseline_output="$1"
    local warnings

    if warnings="$(grep -Ein '(^|[[:space:]])warning:|ignoring an undefined check|contains an include pattern' "$baseline_output")"; then
        log_fail "$LANG_NAME baseline emitted warnings or disabled-check diagnostics"
        printf "%s\n" "$warnings"
        return 1
    fi
}

post_baseline_tests() {
    local project_dir="$1"
    local output
    local diagnostics

    output="$(
        cd "$project_dir" &&
            MIX_ENV=prod ERL_COMPILER_OPTIONS=warnings_as_errors \
                mix compile --force --warnings-as-errors --all-warnings 2>&1
    )" || {
        log_fail "$LANG_NAME production compile failed"
        printf "%s\n" "$output"
        return 1
    }

    if diagnostics="$(printf "%s\n" "$output" | grep -Ein '(^|[[:space:]])warning:|ignoring an undefined check|contains an include pattern')"; then
        log_fail "$LANG_NAME production compile emitted warnings or disabled-check diagnostics"
        printf "%s\n" "$diagnostics"
        return 1
    fi

    log_pass "$LANG_NAME production compile passed without warnings"
}
