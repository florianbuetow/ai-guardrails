#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/helpers.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/runner.sh"

usage() {
    printf "Usage: %s <python|java|go|elixir|cpp|rust|all>\n" "$0"
}

if [ "$#" -ne 1 ]; then
    usage
    exit 1
fi

case "$1" in
    python|java|go|elixir|cpp|rust)
        languages=("$1")
        ;;
    all)
        languages=(python java go elixir cpp rust)
        ;;
    *)
        usage
        exit 1
        ;;
esac

requested_count=${#languages[@]}
passed_languages=0
failed_languages=0

for lang in "${languages[@]}"; do
    lang_config="$SCRIPT_DIR/languages/$lang.sh"

    if [ ! -f "$lang_config" ]; then
        log_fail "Missing language config: $lang_config"
        failed_languages=$((failed_languages + 1))
        continue
    fi

    if (LANG_CONFIG_FILE="$lang_config" LANG_SLUG="$lang" run_language_tests); then
        passed_languages=$((passed_languages + 1))
    else
        failed_languages=$((failed_languages + 1))
    fi
done

log_section "Final summary"
printf "Languages requested: %d\n" "$requested_count"
printf "Languages passed:    %d\n" "$passed_languages"
printf "Languages failed:    %d\n" "$failed_languages"

if [ "$failed_languages" -eq 0 ]; then
    log_pass "All requested language test suites passed"
    exit 0
fi

log_fail "One or more language test suites failed"
exit 1
