#!/usr/bin/env bash

set -euo pipefail

LANG_NAME="Swift macOS"
TEMPLATE_DIR="switftmac"
PROJECT_NAME="test-switftmac"
COPIER_DATA=(
    "project_name=test-switftmac"
    "bundle_identifier=com.example.testswitftmac"
    "project_description=Test native Swift macOS application"
)

check_prerequisites() {
    log_section "$LANG_NAME prerequisites"
    printf "  template: %s, project: %s, copier entries: %d\n" \
        "$TEMPLATE_DIR" "$PROJECT_NAME" "${#COPIER_DATA[@]}"

    require_command copier "Install with: pip install copier"
    require_command just "Install from: https://github.com/casey/just#installation"
    bash "$REPO_ROOT/blueprints/$TEMPLATE_DIR/template/scripts/check-host.sh"
}

validate_violation_output() {
    local violation="$1"
    local output="$2"
    local expected
    case "$violation" in
        force-unwrap) expected='force_unwrapping' ;;
        forbidden-ui-import) expected='architecture.import' ;;
        core-file-io) expected='architecture.effects' ;;
        extra-source-module) expected='architecture.modules' ;;
        shell-process) expected='swift.no-shell-process' ;;
        insecure-transport) expected='swift.no-insecure-transport' ;;
        committed-secret | root-secret) expected='leaks found' ;;
        *)
            log_fail "Unknown Swift violation: $violation"
            return 1
            ;;
    esac
    if ! printf '%s\n' "$output" | grep -F "$expected" >/dev/null; then
        log_fail "Violation '$violation' did not report its intended rule '$expected'"
        printf '%s\n' "$output"
        return 1
    fi
}

post_baseline_tests() {
    local project_dir="$1"
    local app_bundle="$project_dir/build/DerivedData/Build/Products/Debug/$PROJECT_NAME.app"
    local executable="$app_bundle/Contents/MacOS/$PROJECT_NAME"
    local info_plist="$app_bundle/Contents/Info.plist"

    log_section "$LANG_NAME application bundle contract"

    if [ ! -d "$app_bundle" ]; then
        log_fail "Generated project did not produce $app_bundle"
        return 1
    fi
    if [ ! -x "$executable" ]; then
        log_fail "Generated application executable is missing: $executable"
        return 1
    fi
    if ! plutil -lint "$info_plist" >/dev/null; then
        log_fail "Generated application Info.plist is invalid"
        return 1
    fi
    if [ "$(plutil -extract CFBundleIdentifier raw -o - "$info_plist")" != "com.example.testswitftmac" ]; then
        log_fail "Generated application has the wrong bundle identifier"
        return 1
    fi
    if ! codesign --verify --strict "$app_bundle" >/dev/null 2>&1; then
        log_fail "Generated application bundle does not carry a valid signature"
        return 1
    fi
    if ! lipo -info "$executable" | grep -F "arm64" >/dev/null; then
        log_fail "Generated application executable does not contain arm64 code"
        return 1
    fi

    log_pass "Generated project ships a valid signed arm64 macOS application bundle"
    test_staged_secrets "$project_dir"
}

test_staged_secrets() {
    local project_dir="$1"
    local fixture=staged-secret-fixture.json
    local output
    log_section "$LANG_NAME staged secret and deletion contracts"
    (
        cd "$project_dir" || return 1
        printf '%s\n' '{"fakeAwsAccessKey":"AKIAZ3N7Q8P2M5X9L4KC"}' >"$fixture" || return 1
        git add -- "$fixture" || return 1
        printf '%s\n' '{"clean":true}' >"$fixture" || return 1
        if output="$(just code-secrets 2>&1)"; then
            log_fail 'Secret staged but removed from working tree was not detected'
            return 1
        fi
        if ! printf '%s\n' "$output" | grep -F 'leaks found' >/dev/null; then
            log_fail 'Partial-stage check failed for a reason other than secret detection'
            printf '%s\n' "$output"
            return 1
        fi
        git add -- "$fixture" || return 1
        rm "$fixture" || return 1
        just code-secrets || return 1
        git restore --staged -- "$fixture" || return 1
    ) || return 1
    log_pass 'Staged secrets are detected; tracked deletions remain valid'
}
