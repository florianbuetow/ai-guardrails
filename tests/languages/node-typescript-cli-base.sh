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

    test_codeql_init_cache "$project_dir"
}

test_codeql_init_cache() {
    local project_dir="$1"
    local fake_bin
    fake_bin="$(mktemp -d)" || return 1
    if ! cat >"$fake_bin/codeql" <<'EOF'
#!/bin/sh
set -eu
if [ "$1" = "resolve" ] && [ "$2" = "queries" ]; then
    case " $* " in
        *" --format=installedpacks "*) exit 0 ;;
    esac
    test -f "$CODEQL_TEST_MARKER"
elif [ "$1" = "pack" ] && [ "$2" = "download" ]; then
    if [ "$#" -ne 3 ] || [ "$3" != 'codeql/javascript-queries@2.4.7:codeql-suites/javascript-security-extended.qls' ]; then
        printf 'Unexpected CodeQL query pack: %s\n' "$*" >&2
        exit 1
    fi
    : > "$CODEQL_TEST_MARKER"
    printf 'download\n' >> "$CODEQL_TEST_DOWNLOADS"
else
    printf 'Unexpected CodeQL command: %s\n' "$*" >&2
    exit 1
fi
EOF
    then
        rm -rf "$fake_bin"
        return 1
    fi
    if ! cat >"$fake_bin/npm" <<'EOF'
#!/bin/sh
set -eu
test "$1" = "install"
EOF
    then
        rm -rf "$fake_bin"
        return 1
    fi
    if ! chmod +x "$fake_bin/codeql" "$fake_bin/npm"; then
        rm -rf "$fake_bin"
        return 1
    fi

    local attempt
    for attempt in 1 2; do
        if ! (cd "$project_dir" && PATH="$fake_bin:$PATH" \
            CODEQL_TEST_MARKER="$fake_bin/installed" \
            CODEQL_TEST_DOWNLOADS="$fake_bin/downloads" just init); then
            rm -rf "$fake_bin"
            log_fail "CodeQL setup failed on init attempt $attempt"
            return 1
        fi
        if [ ! -f "$fake_bin/downloads" ] || [ "$(wc -l <"$fake_bin/downloads")" -ne 1 ]; then
            rm -rf "$fake_bin"
            log_fail "CodeQL pack must download on the first init and be reused on the second"
            return 1
        fi
    done
    rm -rf "$fake_bin"
    log_pass "CodeQL init downloads a missing pack once and reuses it"
}
