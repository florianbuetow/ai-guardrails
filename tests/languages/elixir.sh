#!/usr/bin/env bash

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
