#!/usr/bin/env bash
#
# Object-file import boundary.
#
# `nm -u` lists every undefined symbol, including internal references
# between this project's own objects. The rule is therefore expressed
# against EXTERNAL imports only:
#
#   project_defined = union of `nm -g --defined-only` over all objects
#   external(obj)   = undefined(obj) - project_defined
#
# io.o is the sole libSystem boundary, so only it may have a non-empty
# external set. Everything else must be empty.

set -euo pipefail

boundary_object="io.o"
object_dir="build/obj"

if [ ! -d "$object_dir" ]; then
    printf "\033[31m✗ Error: %s does not exist — run 'just build' first\033[0m\n" "$object_dir" >&2
    exit 1
fi

objects=()
while IFS= read -r object; do
    objects+=("$object")
done < <(find "$object_dir" -type f -name '*.o' | sort)

if [ "${#objects[@]}" -eq 0 ]; then
    printf "\033[31m✗ Error: no object files in %s\033[0m\n" "$object_dir" >&2
    exit 1
fi

defined="$(mktemp)"
undefined="$(mktemp)"
external="$(mktemp)"
trap 'rm -f "$defined" "$undefined" "$external"' EXIT

nm -g --defined-only "${objects[@]}" | awk 'NF >= 3 { print $3 }' | sort -u >"$defined"

if [ ! -s "$defined" ]; then
    printf "\033[31m✗ Error: no defined symbols found across the object files\033[0m\n" >&2
    exit 1
fi

boundary_seen=0
findings=0

for object in "${objects[@]}"; do
    name="$(basename "$object")"
    nm -u "$object" | awk 'NF { print $1 }' | sort -u >"$undefined"
    comm -23 "$undefined" "$defined" >"$external"

    if [ "$name" = "$boundary_object" ]; then
        boundary_seen=1
        if [ ! -s "$external" ]; then
            printf "\033[31m✗ %s imports nothing external — it is meant to be the libSystem boundary\033[0m\n" "$name" >&2
            findings=$((findings + 1))
        else
            printf "  %s (boundary): %s\n" "$name" "$(tr '\n' ' ' <"$external")"
        fi
        continue
    fi

    if [ -s "$external" ]; then
        printf "\033[31m✗ %s imports external symbols: %s\033[0m\n" "$name" "$(tr '\n' ' ' <"$external")" >&2
        printf "  Only %s may call libSystem. Move the system call there.\n" "$boundary_object" >&2
        findings=$((findings + 1))
    else
        printf "  %s: no external imports\n" "$name"
    fi
done

if [ "$boundary_seen" -eq 0 ]; then
    printf "\033[31m✗ Error: boundary object %s was not built\033[0m\n" "$boundary_object" >&2
    exit 1
fi

if [ "$findings" -gt 0 ]; then
    printf "\033[31m✗ %d layering violation(s)\033[0m\n" "$findings" >&2
    exit 1
fi
