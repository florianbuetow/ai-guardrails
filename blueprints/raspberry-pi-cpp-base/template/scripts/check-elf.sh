#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
    printf 'usage: check-elf.sh BINARY\n' >&2
    exit 1
fi

binary=$1
if [ ! -f "$binary" ] || [ ! -x "$binary" ]; then
    printf 'ELF validation failed: missing or non-executable binary: %s\n' "$binary" >&2
    exit 1
fi
if ! command -v readelf >/dev/null 2>&1; then
    printf 'ELF validation failed: readelf is required\n' >&2
    exit 1
fi

header=$(readelf -hW "$binary")
program=$(readelf -lW "$binary")
dynamic=$(readelf -dW "$binary")

require_text() {
    haystack=$1
    pattern=$2
    description=$3
    if ! printf '%s\n' "$haystack" | grep -Eq "$pattern"; then
        printf 'ELF validation failed: %s\n' "$description" >&2
        exit 1
    fi
}

reject_text() {
    haystack=$1
    pattern=$2
    description=$3
    if printf '%s\n' "$haystack" | grep -Eq "$pattern"; then
        printf 'ELF validation failed: %s\n' "$description" >&2
        exit 1
    fi
}

require_text "$header" 'Class:[[:space:]]+ELF64' 'binary is not ELF64'
require_text "$header" "Data:[[:space:]]+2's complement, little endian" 'binary is not little-endian'
require_text "$header" 'Machine:[[:space:]]+AArch64' 'binary is not AArch64'
require_text "$header" 'Type:[[:space:]]+DYN \(Position-Independent Executable file\)' 'binary is not PIE'
require_text "$program" 'INTERP' 'binary has no dynamic loader interpreter'
require_text "$program" 'GNU_RELRO' 'binary has no GNU_RELRO segment'
require_text "$program" 'GNU_STACK[[:space:]]+0x[0-9a-f]+[[:space:]]+0x[0-9a-f]+[[:space:]]+0x[0-9a-f]+[[:space:]]+0x[0-9a-f]+[[:space:]]+0x[0-9a-f]+[[:space:]]+RW[[:space:]]' 'stack is executable or GNU_STACK is malformed'
reject_text "$program" 'LOAD.*RWE' 'binary contains a writable executable LOAD segment'
require_text "$dynamic" '\(BIND_NOW\)|\(FLAGS\).*BIND_NOW|\(FLAGS_1\).*NOW' 'binary does not use immediate binding'
require_text "$dynamic" '\(FLAGS_1\).*PIE' 'dynamic flags do not mark the binary as PIE'
reject_text "$dynamic" '\((RPATH|RUNPATH)\)' 'binary embeds RPATH or RUNPATH'
reject_text "$dynamic" '\(TEXTREL\)' 'binary contains text relocations'

printf 'ELF validation passed: ELF64 AArch64 PIE, NX stack, RELRO, NOW, no RPATH/RWX\n'
