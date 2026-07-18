#!/usr/bin/env bash
# shellcheck disable=SC2034 # Variables consumed by runner.sh which sources this file

set -euo pipefail

LANG_NAME="Python"
TEMPLATE_DIR="python-cli-base"
PROJECT_NAME="test-cli-project"
COPIER_DATA=(
    "project_name=test-cli-project"
    "package_name=test_cli_project"
    "project_description=Test CLI application"
    "python_version=3.12"
    "author_name=Test Author"
    "author_email=test@example.com"
    "coverage_threshold=80"
)

check_prerequisites() {
    log_section "$LANG_NAME prerequisites"
    require_command copier "Install with: pip install copier"
    require_command just "Install from: https://github.com/casey/just#installation"
    require_command uv "Install from: https://docs.astral.sh/uv/getting-started/installation/"
}

score_grade() {
    local project_dir="$1"
    python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["grade"])' "$project_dir/reports/score/score.json"
}

score_rule_count() {
    local project_dir="$1"
    local rule_prefix="$2"
    python3 -c '
import json
import sys

report = json.load(open(sys.argv[1]))
prefix = sys.argv[2]
total = 0
for check in report["checks"].values():
    for rule_id, count in check["violations"].items():
        if rule_id == prefix or rule_id.startswith(prefix):
            total += count
print(total)
' "$project_dir/reports/score/score.json" "$rule_prefix"
}

post_baseline_tests() {
    local project_dir="$1"
    local grade count entry violation_name expected_id violation_dir backup_dir

    # --- 1. Baseline: the clean project scores exactly 100 ---
    log_section "Python scorer: baseline grade"
    if ! (cd "$project_dir" && UV_EXCLUDE_NEWER="2099-01-01" just score); then
        log_fail "just score failed on the clean project"
        return 1
    fi
    grade="$(score_grade "$project_dir")"
    if [ "$grade" != "100" ]; then
        log_fail "Clean project grade is $grade, expected 100"
        return 1
    fi
    log_pass "Clean project scores 100"

    # --- 2. Determinism: reruns are byte-identical ---
    log_section "Python scorer: determinism"
    local first_report
    first_report="$(mktemp)"
    cp "$project_dir/reports/score/score.json" "$first_report"
    if ! (cd "$project_dir" && UV_EXCLUDE_NEWER="2099-01-01" just score >/dev/null); then
        log_fail "Second just score run failed"
        rm "$first_report"
        return 1
    fi
    if ! cmp -s "$first_report" "$project_dir/reports/score/score.json"; then
        log_fail "score.json is not byte-identical across reruns"
        rm "$first_report"
        return 1
    fi
    rm "$first_report"
    log_pass "score.json byte-identical across reruns"

    # --- 3. Representative injections: one per tool family ---
    local injections=(
        "no-default-values:semgrep/no-default-parameter-values"
        "security-hardcoded-password:bandit/B105"
        "typecheck-wrong-return-type:mypy/return-value"
        "lsp-missing-return-type:mypy/no-untyped-def"
        "style-bad-formatting:ruff-format/would-reformat"
        "deptry-undeclared-import:deptry/DEP001"
    )
    for entry in "${injections[@]}"; do
        violation_name="${entry%%:*}"
        expected_id="${entry#*:}"
        violation_dir="$REPO_ROOT/violations/python/$violation_name"
        log_section "Python scorer: violation $violation_name"
        backup_dir="$(mktemp -d)"
        inject_violation "$violation_dir" "$project_dir" "$backup_dir"
        (cd "$project_dir" && git add -A)
        if ! (cd "$project_dir" && UV_EXCLUDE_NEWER="2099-01-01" just score); then
            log_fail "just score aborted (should have scored) with $violation_name injected"
            restore_violation "$violation_dir" "$project_dir" "$backup_dir"
            return 1
        fi
        grade="$(score_grade "$project_dir")"
        count="$(score_rule_count "$project_dir" "$expected_id")"
        restore_violation "$violation_dir" "$project_dir" "$backup_dir"
        (cd "$project_dir" && git reset -q --hard HEAD && git clean -qfd)
        if [ "$grade" -ge 100 ]; then
            log_fail "Grade $grade did not drop below 100 for $violation_name"
            return 1
        fi
        if [ "$count" -lt 1 ]; then
            log_fail "Expected rule id $expected_id absent for $violation_name"
            return 1
        fi
        log_pass "$violation_name: grade $grade, $expected_id count $count"
    done

    # --- 4. Collection-error probe: broken import is counted, not fatal ---
    log_section "Python scorer: collection-error probe"
    printf '%s\n' \
        '"""Probe: broken import must count as a test failure, not abort the scorer."""' \
        '' \
        'import nonexistent_module_for_score_probe' \
        '' \
        'print(nonexistent_module_for_score_probe.__name__)' \
        > "$project_dir/tests/test_score_probe.py"
    (cd "$project_dir" && git add -A)
    if ! (cd "$project_dir" && UV_EXCLUDE_NEWER="2099-01-01" just score); then
        log_fail "just score aborted on a collection error (should count it)"
        rm -f "$project_dir/tests/test_score_probe.py"
        return 1
    fi
    count="$(score_rule_count "$project_dir" "pytest/test-failure")"
    rm -f "$project_dir/tests/test_score_probe.py"
    (cd "$project_dir" && git reset -q --hard HEAD && git clean -qfd)
    if [ "$count" -lt 1 ]; then
        log_fail "Collection error did not surface as pytest/test-failure"
        return 1
    fi
    log_pass "Collection error counted as pytest/test-failure ($count)"

    # --- 5. Unmapped rule id aborts and names the id ---
    log_section "Python scorer: unmapped weight aborts"
    local weights_file="$project_dir/config/score/weights.toml"
    local score_output
    grep -v '^"semgrep/no-default-parameter-values"' "$weights_file" > "$weights_file.tmp"
    mv "$weights_file.tmp" "$weights_file"
    backup_dir="$(mktemp -d)"
    inject_violation "$REPO_ROOT/violations/python/no-default-values" "$project_dir" "$backup_dir"
    (cd "$project_dir" && git add -A)
    if score_output="$(cd "$project_dir" && UV_EXCLUDE_NEWER="2099-01-01" just score 2>&1)"; then
        log_fail "just score succeeded despite an unmapped rule id"
        restore_violation "$REPO_ROOT/violations/python/no-default-values" "$project_dir" "$backup_dir"
        return 1
    fi
    restore_violation "$REPO_ROOT/violations/python/no-default-values" "$project_dir" "$backup_dir"
    (cd "$project_dir" && git reset -q --hard HEAD && git clean -qfd)
    if ! printf "%s\n" "$score_output" | grep -F "semgrep/no-default-parameter-values" >/dev/null; then
        log_fail "Abort message did not name the missing rule id"
        printf "%s\n" "$score_output"
        return 1
    fi
    log_pass "Unmapped rule id aborts and names the id"
    return 0
}
