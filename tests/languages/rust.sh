#!/usr/bin/env bash

set -euo pipefail

LANG_NAME="Rust"
TEMPLATE_DIR="rust-cli-base"
PROJECT_NAME="test-rust-project"
COPIER_DATA=(
    "project_name=test-rust-project"
    "crate_name=test_rust_project"
    "project_description=Test Rust CLI application"
    "author_name=Test Author"
    "author_email=test@example.com"
    "coverage_threshold=80"
)

check_prerequisites() {
    log_section "$LANG_NAME prerequisites"
    require_command copier "Install with: pip install copier"
    require_command just "Install from: https://github.com/casey/just#installation"
    require_command cargo "Install from: https://rustup.rs/"
}
