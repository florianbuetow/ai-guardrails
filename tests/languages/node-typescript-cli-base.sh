#!/usr/bin/env bash

set -euo pipefail

LANG_NAME="Node.js TypeScript CLI"
TEMPLATE_DIR="node-typescript-cli-base"
PROJECT_NAME="test-node-cli"
COPIER_DATA=(
    "project_name=test-node-cli"
    "project_description=Test Node.js TypeScript CLI"
    "node_version=24.0.0"
    "author_name=Test Author"
    "author_email=test@example.com"
    "coverage_threshold=80"
    "mutation_threshold=80"
)

check_prerequisites() {
    log_section "$LANG_NAME prerequisites"
    printf "  template: %s, project: %s, copier entries: %d\n" \
        "$TEMPLATE_DIR" "$PROJECT_NAME" "${#COPIER_DATA[@]}"

    require_command copier "Install with: pip install copier"
    require_command just "Install from: https://github.com/casey/just#installation"
    require_command node "Install from: https://nodejs.org/"
    require_command npm "npm ships with Node.js: https://nodejs.org/"
    require_command codespell "Install with: brew install codespell"
    require_command semgrep "Install with: brew install semgrep"
    require_command codeql "Install with: brew install codeql"
    require_command gitleaks "Install with: brew install gitleaks"
    require_command shellcheck "Install with: brew install shellcheck"
    require_command shfmt "Install with: brew install shfmt"
}

post_baseline_tests() {
    local project_dir="$1"

    log_section "$LANG_NAME package contract"
    if ! grep -F '"bin"' "$project_dir/package.json" >/dev/null; then
        log_fail "Generated project does not declare an executable bin"
        return 1
    fi
    if ! head -1 "$project_dir/dist/index.js" | grep -F '#!/usr/bin/env node' >/dev/null; then
        log_fail "Built entrypoint is missing the node shebang"
        return 1
    fi
    if ! (cd "$project_dir" && printf '1\n2\n3\n' | node dist/index.js summarize - | grep -F '"mean":2' >/dev/null); then
        log_fail "Built CLI does not summarize stdin"
        return 1
    fi
    log_pass "Generated project ships a working executable CLI"
}
