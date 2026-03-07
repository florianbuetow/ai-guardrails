#!/usr/bin/env bash

set -euo pipefail

run_baseline_test() {
    local temp_dir
    local project_dir

    temp_dir="$(mktemp -d)"
    project_dir="$temp_dir/$PROJECT_NAME"

    log_section "$LANG_NAME baseline"

    if ! generate_project "$temp_dir"; then
        log_fail "Failed to generate $LANG_NAME project"
        cleanup_dir "$temp_dir"
        return 1
    fi

    if (cd "$project_dir" && just ci); then
        log_pass "Baseline CI passed"
        cleanup_dir "$temp_dir"
        return 0
    fi

    log_fail "Baseline CI failed"
    cleanup_dir "$temp_dir"
    return 1
}

run_violation_test() {
    local test_name="$1"
    local violation_dir="$2"
    local temp_dir
    local project_dir

    temp_dir="$(mktemp -d)"
    project_dir="$temp_dir/$PROJECT_NAME"

    log_section "$LANG_NAME violation: $test_name"

    if ! generate_project "$temp_dir"; then
        log_fail "Failed to generate $LANG_NAME project"
        cleanup_dir "$temp_dir"
        return 1
    fi

    if ! (cd "$project_dir" && just ci); then
        log_fail "Baseline sanity check failed before injecting violation"
        cleanup_dir "$temp_dir"
        return 1
    fi

    cp -R "$violation_dir"/. "$project_dir"/

    if (cd "$project_dir" && just ci); then
        log_fail "Violation was not detected by CI"
        cleanup_dir "$temp_dir"
        return 1
    fi

    log_pass "Violation correctly detected"
    cleanup_dir "$temp_dir"
    return 0
}

run_language_tests() {
    local baseline_failed=0
    local total_tests=0
    local passed_tests=0
    local failed_tests=0
    local skipped_tests=0
    local passed_names=()
    local failed_names=()
    local skipped_names=()
    local violation_root
    local violation_dirs=()
    local violation_dir
    local violation_name

    # shellcheck source=/dev/null
    source "$LANG_CONFIG_FILE"

    log_section "Running $LANG_NAME template tests"

    check_prerequisites

    total_tests=$((total_tests + 1))
    if run_baseline_test; then
        passed_tests=$((passed_tests + 1))
        passed_names+=("baseline")
    else
        failed_tests=$((failed_tests + 1))
        failed_names+=("baseline")
        baseline_failed=1
    fi

    violation_root="$REPO_ROOT/violations/$LANG_SLUG"
    if [ -d "$violation_root" ]; then
        while IFS= read -r violation_dir; do
            violation_dirs+=("$violation_dir")
        done < <(find "$violation_root" -mindepth 1 -maxdepth 1 -type d | sort)
    fi

    if [ "$baseline_failed" -eq 1 ]; then
        skipped_tests=${#violation_dirs[@]}
        if [ "$skipped_tests" -gt 0 ]; then
            for violation_dir in "${violation_dirs[@]}"; do
                skipped_names+=("$(basename "$violation_dir")")
            done
            printf "${YELLOW}! Skipping %d violation test(s) because baseline failed${NC}\n" "$skipped_tests"
        fi
    else
        for violation_dir in "${violation_dirs[@]}"; do
            violation_name="$(basename "$violation_dir")"
            total_tests=$((total_tests + 1))
            if run_violation_test "$violation_name" "$violation_dir"; then
                passed_tests=$((passed_tests + 1))
                passed_names+=("$violation_name")
            else
                failed_tests=$((failed_tests + 1))
                failed_names+=("$violation_name")
            fi
        done
    fi

    log_section "$LANG_NAME summary"
    printf "Total:   %d\n" "$total_tests"
    printf "Passed:  %d\n" "$passed_tests"
    printf "Failed:  %d\n" "$failed_tests"
    printf "Skipped: %d\n" "$skipped_tests"
    if [ "${#passed_names[@]}" -gt 0 ]; then
        printf "Passed tests: %s\n" "$(IFS=', '; printf '%s' "${passed_names[*]}")"
    fi
    if [ "${#failed_names[@]}" -gt 0 ]; then
        printf "Failed tests: %s\n" "$(IFS=', '; printf '%s' "${failed_names[*]}")"
    fi
    if [ "${#skipped_names[@]}" -gt 0 ]; then
        printf "Skipped tests: %s\n" "$(IFS=', '; printf '%s' "${skipped_names[*]}")"
    fi

    if [ "$failed_tests" -eq 0 ]; then
        log_pass "$LANG_NAME tests passed"
        return 0
    fi

    log_fail "$LANG_NAME tests failed"
    return 1
}
