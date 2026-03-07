#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_ROOT="$(cd "$LIB_DIR/.." && pwd)"
REPO_ROOT="$(cd "$TESTS_ROOT/.." && pwd)"

log_section() {
    local message="$1"
    printf "\n${BLUE}=== %s ===${NC}\n" "$message"
}

log_pass() {
    local message="$1"
    printf "${GREEN}✓ %s${NC}\n" "$message"
}

log_fail() {
    local message="$1"
    printf "${RED}✗ %s${NC}\n" "$message"
}

require_command() {
    local cmd="$1"
    local install_hint="$2"

    if command -v "$cmd" >/dev/null 2>&1; then
        log_pass "$cmd is installed"
        return 0
    fi

    log_fail "$cmd is not installed"
    printf "  %s\n" "$install_hint"
    exit 1
}

generate_project() {
    local temp_dir="$1"
    local template_path="$REPO_ROOT/blueprints/$TEMPLATE_DIR"
    local target_dir="$temp_dir/$PROJECT_NAME"
    local copier_args=()
    local entry

    for entry in "${COPIER_DATA[@]}"; do
        copier_args+=(--data "$entry")
    done

    copier copy --trust --defaults \
        "${copier_args[@]}" \
        "$template_path" "$target_dir"
}

cleanup_dir() {
    local dir="$1"

    if [ -z "$dir" ] || [ "$dir" = "/" ]; then
        log_fail "Refusing to remove unsafe directory: '$dir'"
        exit 1
    fi

    if [ -d "$dir" ]; then
        rm -rf "$dir"
    fi
}
