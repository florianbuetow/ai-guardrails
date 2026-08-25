#!/usr/bin/env bash

set -euo pipefail

LANG_NAME="TypeScript MCP server"
TEMPLATE_DIR="mcp-server-typescript-base"
PROJECT_NAME="test-mcp-server"
COPIER_DATA=(
    "project_name=test-mcp-server"
    "project_description=Test TypeScript MCP server"
    "node_version=22.19.0"
    "author_name=Test Author"
    "author_email=test@example.com"
    "coverage_threshold=80"
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
}

post_baseline_tests() {
    local project_dir="$1"

    log_section "$LANG_NAME SDK v2 contract"
    if grep -F '"@modelcontextprotocol/sdk"' "$project_dir/package.json" >/dev/null; then
        log_fail "Generated project uses the legacy monolithic MCP SDK"
        return 1
    fi
    if ! grep -F '"@modelcontextprotocol/server": "2.0.0"' "$project_dir/package.json" >/dev/null; then
        log_fail "Generated project does not pin MCP server SDK v2"
        return 1
    fi
    if ! grep -F "serveStdio(createServer)" "$project_dir/src/index.ts" >/dev/null; then
        log_fail "Generated project does not use the v2 serveStdio entrypoint"
        return 1
    fi
    log_pass "Generated project uses MCP TypeScript SDK v2"
}
