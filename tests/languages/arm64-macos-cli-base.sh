#!/usr/bin/env bash

set -euo pipefail

LANG_NAME="ARM64 macOS Assembly CLI"
TEMPLATE_DIR="arm64-macos-cli-base"
PROJECT_NAME="test-arm64-cli"
COPIER_DATA=(
    "project_name=test-arm64-cli"
    "project_description=Test ARM64 macOS assembly CLI"
    "author_name=Test Author"
    "author_email=test@example.com"
)

check_prerequisites() {
    log_section "$LANG_NAME prerequisites"
    printf "  template: %s, project: %s, copier entries: %d\n" \
        "$TEMPLATE_DIR" "$PROJECT_NAME" "${#COPIER_DATA[@]}"

    if [ "$(uname -s)" != "Darwin" ]; then
        log_fail "$LANG_NAME requires macOS (found $(uname -s))"
        exit 1
    fi
    if [ "$(uname -m)" != "arm64" ]; then
        log_fail "$LANG_NAME requires Apple Silicon (found $(uname -m))"
        exit 1
    fi

    require_command copier "Install with: pip install copier"
    require_command just "Install from: https://github.com/casey/just#installation"
    require_command xcrun "Install the Xcode Command Line Tools: xcode-select --install"
    require_command otool "Install the Xcode Command Line Tools: xcode-select --install"
    require_command nm "Install the Xcode Command Line Tools: xcode-select --install"
    require_command lipo "Install the Xcode Command Line Tools: xcode-select --install"
    require_command codesign "Install the Xcode Command Line Tools: xcode-select --install"
    require_command lldb "Install the Xcode Command Line Tools: xcode-select --install"
    require_command brew "Homebrew LLVM provides FileCheck, llvm-objdump, llvm-readobj and llvm-mca: https://brew.sh"
    require_command codespell "Install with: brew install codespell"
    require_command semgrep "Install with: brew install semgrep"
    require_command shellcheck "Install with: brew install shellcheck"
    require_command shfmt "Install with: brew install shfmt"

    local llvm_bin
    if ! llvm_bin="$(brew --prefix llvm 2>/dev/null)"; then
        log_fail "Homebrew LLVM is not installed"
        printf "  Install with: brew install llvm\n"
        exit 1
    fi
    local tool
    for tool in FileCheck llvm-objdump llvm-readobj llvm-mca; do
        if [ ! -x "$llvm_bin/bin/$tool" ]; then
            log_fail "$tool is missing from $llvm_bin/bin"
            printf "  Install with: brew install llvm\n"
            exit 1
        fi
        log_pass "$tool is installed"
    done
}

post_baseline_tests() {
    local project_dir="$1"
    local binary="$project_dir/build/$PROJECT_NAME"

    log_section "$LANG_NAME binary contract"

    if [ ! -x "$binary" ]; then
        log_fail "Generated project did not produce an executable at build/$PROJECT_NAME"
        return 1
    fi

    if ! lipo -info "$binary" | grep -F "is architecture: arm64" >/dev/null; then
        log_fail "Built binary is not a single-architecture arm64 Mach-O"
        lipo -info "$binary"
        return 1
    fi

    if ! codesign --verify --strict "$binary" >/dev/null 2>&1; then
        log_fail "Built binary does not carry a valid signature"
        return 1
    fi

    if ! otool -L "$binary" | tail -n +2 | grep -F "/usr/lib/libSystem.B.dylib" >/dev/null; then
        log_fail "Built binary does not link libSystem"
        return 1
    fi

    local output
    output="$(printf '1\n2\n3\n' | "$binary" sum -)"
    if [ "$output" != "count=3 sum=6 max=3" ]; then
        log_fail "Built CLI did not summarize stdin (got: $output)"
        return 1
    fi

    local status=0
    "$binary" >/dev/null 2>&1 || status=$?
    if [ "$status" != "2" ]; then
        log_fail "Built CLI did not exit 2 on a usage error (got: $status)"
        return 1
    fi

    log_pass "Generated project ships a signed arm64 CLI with the expected exit contract"
}
