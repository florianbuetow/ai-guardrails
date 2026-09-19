#!/usr/bin/env bash
#
# Final-binary validation, in two halves so each maps to one recipe.
#
#   --security   import allowlist, dylib allowlist, code signature
#   --structure  architecture, platform metadata, segment permissions
#
# Both allowlists are compared by EXACT set equality. An unexpected import
# and a stale allowlist entry are both errors: a subset check would let the
# allowlist drift away from what the binary really does.

set -euo pipefail

usage() {
    printf "usage: %s --security | --structure\n" "$0" >&2
}

if [ "$#" -ne 1 ]; then
    usage
    exit 1
fi

binary_dir="build"
binaries=()
while IFS= read -r candidate; do
    binaries+=("$candidate")
done < <(find "$binary_dir" -maxdepth 1 -type f -perm -u+x | sort)

if [ "${#binaries[@]}" -ne 1 ]; then
    printf "\033[31m✗ Error: expected exactly one executable in %s, found %d — run 'just build'\033[0m\n" \
        "$binary_dir" "${#binaries[@]}" >&2
    exit 1
fi
binary="${binaries[0]}"

expected="$(mktemp)"
actual="$(mktemp)"
trap 'rm -f "$expected" "$actual"' EXIT

compare_sets() {
    local label="$1"
    local allowlist="$2"
    local remedy="$3"

    if [ ! -f "$allowlist" ]; then
        printf "\033[31m✗ Error: allowlist %s is missing\033[0m\n" "$allowlist" >&2
        exit 1
    fi

    grep -v '^[[:space:]]*$' "$allowlist" | grep -v '^[[:space:]]*#' | sort -u >"$expected"

    if diff -u "$expected" "$actual" >/dev/null; then
        printf "  %s matches the allowlist (%d entries)\n" "$label" "$(wc -l <"$expected" | tr -d ' ')"
        return 0
    fi

    printf "\033[31m✗ %s does not match %s\033[0m\n" "$label" "$allowlist" >&2
    while IFS= read -r entry; do
        printf "    unexpected: %s\n" "$entry" >&2
    done < <(comm -13 "$expected" "$actual")
    while IFS= read -r entry; do
        printf "    missing:    %s\n" "$entry" >&2
    done < <(comm -23 "$expected" "$actual")
    printf "  %s\n" "$remedy" >&2
    return 1
}

check_security() {
    local findings=0

    nm -u "$binary" | awk 'NF { print $1 }' | sort -u >"$actual"
    compare_sets "imports" "config/allowed-imports.txt" \
        "Adding an import is an ordinary reviewed source change: update config/allowed-imports.txt deliberately." ||
        findings=$((findings + 1))

    otool -L "$binary" | tail -n +2 | awk '{ print $1 }' | sort -u >"$actual"
    compare_sets "linked dylibs" "config/allowed-dylibs.txt" \
        "This project links libSystem only. Do not add frameworks." ||
        findings=$((findings + 1))

    if codesign --verify --strict --verbose "$binary" 2>&1 | sed 's/^/    /'; then
        printf "  code signature is valid\n"
    else
        printf "\033[31m✗ code signature is invalid — re-sign after any step that rewrites the binary\033[0m\n" >&2
        findings=$((findings + 1))
    fi

    return "$findings"
}

# The project's pinned build target. config/target.txt is the single input
# every build step reads; this constant is the contract it must satisfy.
# Changing the target is a deliberate decision that has to update both.
PINNED_TARGET="arm64-apple-macos11"

check_structure() {
    local findings=0
    local architectures
    local platform
    local minos
    local configured_target
    local expected_minos

    configured_target="$(scripts/build-target.sh)"
    if [ "$configured_target" != "$PINNED_TARGET" ]; then
        printf "\033[31m✗ config/target.txt is %s, but this project is pinned to %s\033[0m\n" \
            "$configured_target" "$PINNED_TARGET" >&2
        printf "  macOS 11 is the first Apple Silicon release and this project uses only basic\n" >&2
        printf "  libSystem functionality. Raising the floor drops compatibility for nothing.\n" >&2
        findings=$((findings + 1))
    else
        printf "  build target: %s\n" "$configured_target"
    fi
    expected_minos="${PINNED_TARGET##*macos}.0"

    architectures="$(lipo -info "$binary" | sed 's/.*architecture: //; s/.*are: //')"
    if [ "$architectures" != "arm64" ]; then
        printf "\033[31m✗ expected an arm64-only binary, found: %s\033[0m\n" "$architectures" >&2
        findings=$((findings + 1))
    else
        printf "  architecture: arm64\n"
    fi

    platform="$(otool -l "$binary" | awk '/LC_BUILD_VERSION/ { found = 1 } found && $1 == "platform" { print $2; exit }')"
    minos="$(otool -l "$binary" | awk '/LC_BUILD_VERSION/ { found = 1 } found && $1 == "minos" { print $2; exit }')"

    if [ "$platform" != "1" ]; then
        printf "\033[31m✗ expected LC_BUILD_VERSION platform 1 (macOS), found: %s\033[0m\n" "${platform:-none}" >&2
        findings=$((findings + 1))
    else
        printf "  platform: macOS\n"
    fi

    if [ "$minos" != "$expected_minos" ]; then
        printf "\033[31m✗ expected minos %s, found: %s\033[0m\n" "$expected_minos" "${minos:-none}" >&2
        printf "  The deployment target is fixed at macOS 11, the first Apple Silicon release.\n" >&2
        findings=$((findings + 1))
    else
        printf "  minimum macOS: %s\n" "$minos"
    fi

    if otool -l "$binary" | grep -q LC_LOAD_WEAK_DYLIB; then
        printf "\033[31m✗ binary carries a weak dylib load command\033[0m\n" >&2
        findings=$((findings + 1))
    else
        printf "  no weak dylib load commands\n"
    fi

    local llvm_bin
    llvm_bin="$(scripts/llvm-bin.sh)"
    while IFS= read -r segment; do
        printf "\033[31m✗ segment %s is both writable and executable\033[0m\n" "$segment" >&2
        findings=$((findings + 1))
    done < <("$llvm_bin/llvm-readobj" --macho-segment "$binary" |
        awk '/Name:/ { name = $2 } /initprot:/ { if ($2 ~ /w/ && $2 ~ /x/) print name }')

    if [ "$findings" -eq 0 ]; then
        printf "  no writable-executable segments\n"
    fi

    return "$findings"
}

case "$1" in
    --security)
        if ! check_security; then
            printf "\033[31m✗ binary security checks failed\033[0m\n" >&2
            exit 1
        fi
        ;;
    --structure)
        if ! check_structure; then
            printf "\033[31m✗ Mach-O structure checks failed\033[0m\n" >&2
            exit 1
        fi
        ;;
    *)
        usage
        exit 1
        ;;
esac
