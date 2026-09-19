#!/usr/bin/env bash
#
# Conservative source hygiene for assembly.
#
# There is no canonical ARM assembly formatter, and this project does not
# invent one. Only three transformations are applied, each chosen because
# it cannot change what the assembler sees:
#
#   1. strip trailing whitespace
#   2. collapse runs of three or more blank lines to one
#   3. end the file with exactly one newline
#
# No column alignment, no operand reflow, no comment repositioning.

set -euo pipefail

usage() {
    printf "usage: %s --check | --write\n" "$0" >&2
}

if [ "$#" -ne 1 ]; then
    usage
    exit 1
fi

case "$1" in
    --check) mode="check" ;;
    --write) mode="write" ;;
    *)
        usage
        exit 1
        ;;
esac

sources=()
while IFS= read -r file; do
    sources+=("$file")
done < <(find src tests include -type f \( -name '*.S' -o -name '*.inc' \) | sort)

if [ "${#sources[@]}" -eq 0 ]; then
    printf "\033[31m✗ Error: no assembly sources found under src, tests or include\033[0m\n" >&2
    exit 1
fi

normalize() {
    awk '
    {
        line = $0
        sub(/[ \t]+$/, "", line)
        if (line == "") {
            blanks++
            next
        }
        if (blanks > 0) {
            emit = (blanks >= 3) ? 1 : blanks
            for (i = 0; i < emit; i++) {
                print ""
            }
            blanks = 0
        }
        print line
    }
    ' "$1"
}

offenders=0
for source in "${sources[@]}"; do
    normalized="$(mktemp)"
    normalize "$source" >"$normalized"
    if cmp -s "$source" "$normalized"; then
        rm -f "$normalized"
        continue
    fi
    if [ "$mode" = "write" ]; then
        cat "$normalized" >"$source"
        printf "  formatted %s\n" "$source"
    else
        printf "\033[31m✗ %s needs formatting (run: just code-format)\033[0m\n" "$source" >&2
        offenders=$((offenders + 1))
    fi
    rm -f "$normalized"
done

if [ "$offenders" -gt 0 ]; then
    printf "\033[31m✗ %d file(s) fail source hygiene\033[0m\n" "$offenders" >&2
    exit 1
fi
