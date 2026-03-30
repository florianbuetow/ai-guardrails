#!/usr/bin/env bash

set -euo pipefail

# Back up original files before injecting a violation so we can restore them.
inject_violation() {
    local violation_dir="$1"
    local project_dir="$2"
    local backup_dir="$3"

    # Find all files in the violation directory (relative paths)
    while IFS= read -r rel_path; do
        local src="$violation_dir/$rel_path"
        local dst="$project_dir/$rel_path"
        local bak="$backup_dir/$rel_path"

        # Skip the "check" metadata file
        if [ "$rel_path" = "check" ]; then
            continue
        fi

        # Back up the original if it exists
        if [ -f "$dst" ]; then
            mkdir -p "$(dirname "$bak")"
            cp "$dst" "$bak"
        fi

        # Copy the violation file in
        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
    done < <(cd "$violation_dir" && find . -type f | sed 's|^\./||')
}

# Restore backed-up files and remove any files that were added (not overwritten).
restore_violation() {
    local violation_dir="$1"
    local project_dir="$2"
    local backup_dir="$3"

    while IFS= read -r rel_path; do
        local dst="$project_dir/$rel_path"
        local bak="$backup_dir/$rel_path"

        if [ "$rel_path" = "check" ]; then
            continue
        fi

        if [ -f "$bak" ]; then
            cp "$bak" "$dst"
        else
            rm -f "$dst"
        fi
    done < <(cd "$violation_dir" && find . -type f | sed 's|^\./||')

    rm -rf "$backup_dir"
}

run_language_tests() {
    local temp_dir
    local project_dir
    local violation_root
    local violation_dirs=()
    local violation_dir
    local violation_name
    local check_recipe
    local backup_dir
    local total_tests=0
    local passed_tests=0

    # shellcheck source=/dev/null
    source "$LANG_CONFIG_FILE"

    log_section "Running $LANG_NAME template tests"

    check_prerequisites

    # --- One-time project setup ---
    temp_dir="$(mktemp -d)"
    project_dir="$temp_dir/$PROJECT_NAME"

    log_section "$LANG_NAME project setup"

    if ! generate_project "$temp_dir"; then
        log_fail "Failed to generate $LANG_NAME project"
        cleanup_dir "$temp_dir"
        return 1
    fi
    log_pass "Project generated"

    # --- Baseline: full CI must pass ---
    log_section "$LANG_NAME baseline"

    # Disable uv exclude-newer during testing — the supply-chain protection
    # intentionally pins older packages, which can cause pip-audit to flag
    # vulnerabilities whose fixes are too recent to install.
    if ! (cd "$project_dir" && UV_EXCLUDE_NEWER="2099-01-01" just ci); then
        log_fail "Baseline CI failed"
        cleanup_dir "$temp_dir"
        return 1
    fi
    log_pass "Baseline CI passed"
    total_tests=$((total_tests + 1))
    passed_tests=$((passed_tests + 1))

    # --- Discover violation tests (skip in baseline mode) ---
    violation_root="$REPO_ROOT/violations/$LANG_SLUG"
    if [ "${TEST_MODE:-all}" != "baseline" ] && [ -d "$violation_root" ]; then
        while IFS= read -r violation_dir; do
            violation_dirs+=("$violation_dir")
        done < <(find "$violation_root" -mindepth 1 -maxdepth 1 -type d | sort)
    fi

    # --- Run each violation test (fail fast) ---
    for violation_dir in ${violation_dirs[@]+"${violation_dirs[@]}"}; do
        violation_name="$(basename "$violation_dir")"
        total_tests=$((total_tests + 1))

        # Determine which check recipe to run — every violation must declare one
        if [ ! -f "$violation_dir/check" ]; then
            log_fail "Violation '$violation_name' is missing its 'check' file (must contain the just recipe name)"
            cleanup_dir "$temp_dir"
            return 1
        fi
        check_recipe="$(cat "$violation_dir/check")"
        if [ -z "$check_recipe" ]; then
            log_fail "Violation '$violation_name' has an empty 'check' file"
            cleanup_dir "$temp_dir"
            return 1
        fi

        log_section "$LANG_NAME violation: $violation_name (just $check_recipe)"

        # Inject violation files (with backup) and stage for semgrep
        backup_dir="$(mktemp -d)"
        inject_violation "$violation_dir" "$project_dir" "$backup_dir"
        (cd "$project_dir" && git add -A)

        # Run the targeted check — it must fail
        local check_output
        check_output="$(cd "$project_dir" && just "$check_recipe" 2>&1)" && {
            log_fail "Violation '$violation_name' was NOT detected by 'just $check_recipe'"
            printf "%s\n" "$check_output"
            restore_violation "$violation_dir" "$project_dir" "$backup_dir"
            cleanup_dir "$temp_dir"
            return 1
        }

        log_pass "Violation '$violation_name' correctly detected"
        passed_tests=$((passed_tests + 1))

        # Restore original files and git state for the next test
        restore_violation "$violation_dir" "$project_dir" "$backup_dir"
        (cd "$project_dir" && git checkout -q . && git clean -qfd)
    done

    # --- Cleanup ---
    cleanup_dir "$temp_dir"

    log_section "$LANG_NAME summary"
    printf "Total:  %d\n" "$total_tests"
    printf "Passed: %d\n" "$passed_tests"
    log_pass "$LANG_NAME — all tests passed"
    return 0
}
