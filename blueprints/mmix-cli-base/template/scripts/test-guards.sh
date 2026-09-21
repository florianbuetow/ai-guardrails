#!/bin/sh
set -eu
# Negative assertions prove malformed/absent reports cannot silently pass.
dollar='$'
printf '' > build/empty.txt
if build/assert object build/empty.txt > build/negative.txt 2>&1; then
    printf 'Object guard accepted an empty report\n' >&2
    exit 1
fi
printf 'Program profile:\n' > build/empty-profile.txt
if build/assert coverage build/object.txt build/main.mml build/empty-profile.txt > build/negative.txt 2>&1; then
    printf 'Coverage guard accepted an empty profile\n' >&2
    exit 1
fi
if build/assert coverage build/object.txt build/empty.txt build/profile.txt > build/negative.txt 2>&1; then
    printf 'Listing guard accepted an empty listing\n' >&2
    exit 1
fi

printf '%s\n' \
    'Program profile:' \
    '         1. 0000000000000100: 23fffe00 (ADDUI)' \
    '         1. 0000000000000104: 00000701 (TRAP)' \
    '         1. 0000000000000108: e3ff0000 (SETL)' \
    > build/omitted-profile.txt
if build/assert coverage build/object.txt build/main.mml build/omitted-profile.txt > build/negative.txt 2>&1; then
    printf 'Coverage guard accepted a profile with an omitted instruction\n' >&2
    exit 1
fi

printf '%s\n' \
    'Program profile:' \
    '         1. 0000000000000100: 23fffe00 (ADDUI)' \
    '         1. 0000000000000104: 00000701 (TRAP)' \
    '         0. 0000000000000108: e3ff0000 (SETL)' \
    '         1. 000000000000010c: 00000000 (TRAP)' \
    > build/zero-hit-profile.txt
if build/assert coverage build/object.txt build/main.mml build/zero-hit-profile.txt > build/negative.txt 2>&1; then
    printf 'Coverage guard accepted a zero-hit instruction\n' >&2
    exit 1
fi

printf '%s\n' \
    'Program profile:' \
    '         1. 0000000000000100: 23fffe01 (ADDUI)' \
    '         1. 0000000000000104: 00000701 (TRAP)' \
    '         1. 0000000000000108: e3ff0000 (SETL)' \
    '         1. 000000000000010c: 00000000 (TRAP)' \
    > build/wrong-word-profile.txt
if build/assert coverage build/object.txt build/main.mml build/wrong-word-profile.txt > build/negative.txt 2>&1; then
    printf 'Coverage guard accepted a profile word that differs from the object\n' >&2
    exit 1
fi

printf '%s\n' \
    '0000000000000100: 23fffe00 ("src/main.mms", line 5)' \
    '0000000000000104: 00000701 (line 6)' \
    '0000000000000108: e3ff0000 (line 7)' \
    '000000000000010c: 00000000 (line 8)' \
    'g255: 0000000000000100' \
    > build/missing-main-object.txt
if build/assert object build/missing-main-object.txt > build/negative.txt 2>&1; then
    printf 'Object guard accepted an object report without Main\n' >&2
    exit 1
fi

printf '%s\n' \
    '0000000000000100: 23fffe00 ("src/main.mms", line 5)' \
    '0000000000000104: 00000701 (line 6)' \
    '0000000000000108: e3ff0000 (line 7)' \
    '000000000000010c: 00000000 (line 8)' \
    'g255: 2000000000000000' \
    '    Main = #0100 (1)' \
    > build/wrong-entry-object.txt
if build/assert object build/wrong-entry-object.txt > build/negative.txt 2>&1; then
    printf 'Object guard accepted an entry register in the data segment\n' >&2
    exit 1
fi

printf '%s\n' \
    "0000000000000100:  Main    LDA     ${dollar}255,Message" \
    ' ...100: 23fffe01' \
    ' ...104: 00000701          TRAP    0,Fputs,StdOut' \
    " ...108: e3ff0000          SETL    ${dollar}255,0" \
    ' ...10c: 00000000          TRAP    0,Halt,0' \
    > build/mismatched-listing.txt
if build/assert coverage build/object.txt build/mismatched-listing.txt build/profile.txt > build/negative.txt 2>&1; then
    printf 'Listing guard accepted an instruction word that differs from the object\n' >&2
    exit 1
fi

printf 'assembler warning\n' > build/warning.txt
if build/assert empty build/warning.txt > build/negative.txt 2>&1; then
    printf 'Assembler guard accepted a warning\n' >&2
    exit 1
fi
printf '%s\n' \
    '        LOC #100' \
    'Main    BYTE 256' \
    "        SETL ${dollar}255,0" \
    '        TRAP 0,Halt,0' \
    > build/warning.mms
if ! build/mmixal -o build/warning.mmo build/warning.mms > build/actual-warning.txt 2>&1; then
    printf 'Warning fixture did not exercise the assembler success-with-warning path\n' >&2
    exit 1
fi
if build/assert empty build/actual-warning.txt > build/negative.txt 2>&1; then
    printf 'Assembler guard accepted a real MMIXAL warning\n' >&2
    exit 1
fi
printf 'stray.mmo\000' > build/artifact-fixture.txt
if build/assert artifacts build/artifact-fixture.txt > build/negative.txt 2>&1; then
    printf 'Artifact guard accepted a stray MMO\n' >&2
    exit 1
fi
printf 'stray.mmb\000' > build/artifact-fixture.txt
if build/assert artifacts build/artifact-fixture.txt > build/negative.txt 2>&1; then
    printf 'Artifact guard accepted a stray MMB\n' >&2
    exit 1
fi
printf 'build/main.mmo\000' > build/artifact-fixture.txt
if build/assert tracked build/artifact-fixture.txt > build/negative.txt 2>&1; then
    printf 'Artifact guard accepted a tracked build output\n' >&2
    exit 1
fi

if [ -e native-fixture ]; then
    printf 'Refusing to overwrite existing native-fixture\n' >&2
    exit 1
fi
trap 'rm -f native-fixture' EXIT HUP INT TERM
printf '\177ELF' > native-fixture
printf 'native-fixture\000' > build/artifact-fixture.txt
if build/assert artifacts build/artifact-fixture.txt > build/negative.txt 2>&1; then
    printf 'Artifact guard accepted untracked native binary content\n' >&2
    exit 1
fi
rm -f native-fixture
trap - EXIT HUP INT TERM

printf 'Local report guard regression tests passed\n'
