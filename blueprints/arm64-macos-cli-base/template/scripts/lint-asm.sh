#!/usr/bin/env bash
#
# ARM64 source style policy.
#
# Every rule here is mechanical and needs no understanding of the
# instruction stream:
#
#   1. no tab characters
#   2. a line starts at column 0 or is indented by exactly four spaces
#   3. one instruction per line — no ';' separators outside strings
#   4. comments use '//', never ';' or '@'
#   5. mnemonics are lowercase; ALL_CAPS is reserved for macros declared
#      in include/*.inc
#   6. register names are lowercase

set -euo pipefail

macros="$(mktemp)"
trap 'rm -f "$macros"' EXIT
grep -ho '^\.macro[[:space:]]\+[A-Za-z_][A-Za-z0-9_]*' include/*.inc |
    awk '{print $2}' | sort -u >"$macros"

if [ ! -s "$macros" ]; then
    printf "\033[31m✗ Error: no macros declared in include/*.inc\033[0m\n" >&2
    exit 1
fi

sources=()
while IFS= read -r file; do
    sources+=("$file")
done < <(find src tests include -type f \( -name '*.S' -o -name '*.inc' \) | sort)

if [ "${#sources[@]}" -eq 0 ]; then
    printf "\033[31m✗ Error: no assembly sources found under src, tests or include\033[0m\n" >&2
    exit 1
fi

findings=0

report() {
    printf "\033[31m✗ %s:%s: %s\033[0m\n" "$1" "$2" "$3" >&2
    findings=$((findings + 1))
}

for source in "${sources[@]}"; do
    # Collect the lines first so the reporting loop never redirects from the
    # same path it names in its messages.
    lines=()
    while IFS= read -r collected; do
        lines+=("$collected")
    done <"$source"

    line_number=0
    for line in ${lines[@]+"${lines[@]}"}; do
        line_number=$((line_number + 1))

        case "$line" in
            *"$(printf '\t')"*)
                report "$source" "$line_number" "tab character (use four spaces)"
                ;;
        esac

        # Strip string literals before punctuation checks so that a ';' or
        # '@' inside .asciz data is not mistaken for a comment.
        stripped="$(printf '%s' "$line" | sed 's/"[^"]*"//g')"
        # Drop an end-of-line comment; '@PAGE'/'@PAGEOFF' relocations are
        # not comments and must survive this step.
        code="${stripped%%//*}"

        case "$code" in
            *';'*)
                report "$source" "$line_number" "';' separator or comment (one instruction per line, comments use //)"
                ;;
        esac

        [ -z "${code// /}" ] && continue

        indent="${code%%[! ]*}"
        case "${#indent}" in
            0 | 4) ;;
            *)
                report "$source" "$line_number" "indent must be 0 or 4 spaces, found ${#indent}"
                ;;
        esac

        token="$(printf '%s' "$code" | awk '{print $1}')"
        case "$token" in
            '' | .* | \#* | *:) ;;
            *)
                if printf '%s' "$token" | grep -q '[A-Z]'; then
                    if ! grep -qx "$token" "$macros"; then
                        report "$source" "$line_number" "'$token' is not lowercase and is not a macro from include/*.inc"
                    fi
                elif printf '%s' "$token" | grep -qv '^[a-z][a-z0-9._]*$'; then
                    report "$source" "$line_number" "mnemonic '$token' must be lowercase"
                fi
                ;;
        esac

        if printf '%s' "$code" | grep -qE '(^|[^A-Za-z0-9_])(X|W)[0-9]+([^A-Za-z0-9_]|$)'; then
            report "$source" "$line_number" "register names must be lowercase"
        fi
    done
done

if [ "$findings" -gt 0 ]; then
    printf "\033[31m✗ %d style finding(s)\033[0m\n" "$findings" >&2
    exit 1
fi
