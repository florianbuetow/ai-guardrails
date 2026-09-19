#!/usr/bin/env bash
#
# ABI source discipline.
#
# This script does NOT attempt to prove that arbitrary assembly is
# ABI-correct — static textual analysis cannot do that. It enforces a
# discipline that makes the common failure modes unrepresentable, and
# leaves the rest to the unit tests and the disassembly assertions.
#
#   1. every exported symbol is opened by FUNC and closed by ENDFUNC
#   2. frame allocation goes through the ABI macros, never raw sp writes
#   3. x18 is never touched — Apple reserves it
#   4. every symbol exported from src/lib is referenced by a test

set -euo pipefail

findings=0

report() {
    printf "\033[31m✗ %s\033[0m\n" "$1" >&2
    findings=$((findings + 1))
}

sources=()
while IFS= read -r file; do
    sources+=("$file")
done < <(find src tests -type f -name '*.S' | sort)

if [ "${#sources[@]}" -eq 0 ]; then
    printf "\033[31m✗ Error: no assembly sources found under src or tests\033[0m\n" >&2
    exit 1
fi

# --- Rule 1: exported symbols go through FUNC / ENDFUNC ---------------------
for source in "${sources[@]}"; do
    while IFS= read -r symbol; do
        report "$source: '.globl $symbol' declared directly; use 'FUNC $symbol'"
    done < <(grep -o '^[[:space:]]*\.globl[[:space:]]\+[A-Za-z_][A-Za-z0-9_]*' "$source" | awk '{print $2}')

    opened="$(awk '/^FUNC[[:space:]]/ { n++ } END { print n + 0 }' "$source")"
    closed="$(awk '/^ENDFUNC[[:space:]]/ { n++ } END { print n + 0 }' "$source")"
    if [ "$opened" != "$closed" ]; then
        report "$source: $opened FUNC vs $closed ENDFUNC — every exported function must be closed"
    fi

    while IFS= read -r name; do
        if ! grep -q "^ENDFUNC[[:space:]]\+$name\$" "$source"; then
            report "$source: FUNC $name has no matching 'ENDFUNC $name'"
        fi
    done < <(grep '^FUNC[[:space:]]' "$source" | awk '{print $2}')

    local_opened="$(awk '/^LOCAL_FUNC[[:space:]]/ { n++ } END { print n + 0 }' "$source")"
    local_closed="$(awk '/^LOCAL_ENDFUNC[[:space:]]/ { n++ } END { print n + 0 }' "$source")"
    if [ "$local_opened" != "$local_closed" ]; then
        report "$source: $local_opened LOCAL_FUNC vs $local_closed LOCAL_ENDFUNC"
    fi
done

# --- Rule 2: frame allocation only through the ABI macros -------------------
for source in "${sources[@]}"; do
    while IFS= read -r hit; do
        report "$source:$hit — raw stack-pointer arithmetic; use FRAME_PUSH / FRAME_POP"
    done < <(grep -n -E '^[[:space:]]*(add|sub)[[:space:]]+sp[[:space:]]*,' "$source" | cut -d: -f1,2)

    while IFS= read -r hit; do
        report "$source:$hit — raw stack writeback; use FRAME_PUSH / FRAME_POP"
    done < <(grep -n -E '^[[:space:]]*(stp|ldp)[[:space:]].*\[sp[^]]*\][!]|^[[:space:]]*(stp|ldp)[[:space:]].*\[sp\],' "$source" | cut -d: -f1,2)
done

# --- Rule 3: x18 is reserved ------------------------------------------------
for source in "${sources[@]}"; do
    while IFS= read -r hit; do
        report "$source:$hit — x18/w18 is reserved by Apple and must never be used"
    done < <(grep -n -E '(^|[^A-Za-z0-9_])[xw]18([^A-Za-z0-9_]|$)' "$source" | cut -d: -f1,2)
done

# --- Rule 4: every library export is exercised by a test --------------------
lib_sources=()
while IFS= read -r file; do
    lib_sources+=("$file")
done < <(find src/lib -type f -name '*.S' | sort)

if [ "${#lib_sources[@]}" -eq 0 ]; then
    printf "\033[31m✗ Error: no library sources found under src/lib\033[0m\n" >&2
    exit 1
fi

for source in "${lib_sources[@]}"; do
    while IFS= read -r name; do
        if ! grep -rq -- "$name" tests; then
            report "$source: exported symbol '$name' is not referenced by any test"
        fi
    done < <(grep '^FUNC[[:space:]]' "$source" | awk '{print $2}')
done

if [ "$findings" -gt 0 ]; then
    printf "\033[31m✗ %d ABI discipline finding(s)\033[0m\n" "$findings" >&2
    exit 1
fi
