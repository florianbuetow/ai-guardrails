#!/usr/bin/env bash
# shellcheck disable=SC2034 # Variables consumed by runner.sh which sources this file

set -euo pipefail

LANG_NAME="C++"
TEMPLATE_DIR="cpp-cli-base"
PROJECT_NAME="test-cpp-project"
COPIER_DATA=(
    "project_name=test-cpp-project"
    "project_description=Test CLI application"
    "cpp_standard=23"
    "author_name=Test Author"
    "author_email=test@example.com"
    "coverage_threshold=80"
)

check_prerequisites() {
    log_section "$LANG_NAME prerequisites"
    require_command copier "Install with: pip install copier"
    require_command just "Install from: https://github.com/casey/just#installation"
    require_command cmake "Install with: brew install cmake"

    if command -v c++ >/dev/null 2>&1 || command -v g++ >/dev/null 2>&1; then
        log_pass "c++ or g++ is installed"
    else
        log_fail "c++ or g++ is not installed"
        printf "  Install a C++ compiler (Xcode Command Line Tools or GCC)\n"
        exit 1
    fi

    require_command clang-format "Install with: brew install clang-format"
    require_command clang-tidy "Install with: brew install llvm"
    require_command cppcheck "Install with: brew install cppcheck"
    require_command flawfinder "Install with: brew install flawfinder"
    require_command codespell "Install with: brew install codespell"
    require_command semgrep "Install with: brew install semgrep"
    require_command lcov "Install with: brew install lcov"
    require_command infer "Install from: https://github.com/facebook/infer"
}
