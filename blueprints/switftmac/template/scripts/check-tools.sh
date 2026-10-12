#!/bin/bash
set -euo pipefail

bash scripts/check-host.sh
# shellcheck source=environment.sh
source scripts/environment.sh
expected_tools=$'gitleaks\nosv-scanner\nshellcheck\nshfmt\nswiftlint\nuv\nxcodegen'
actual_tools="$(cut -f 1 config/tools.lock.tsv | LC_ALL=C sort)"
if [ "$actual_tools" != "$expected_tools" ]; then
    printf 'Required native tool inventory is incomplete or duplicated\n' >&2
    exit 1
fi
while IFS=$'\t' read -r name expected kind url checksum; do
    [ -n "$kind" ] && [ -n "$url" ] && [ -n "$checksum" ]
    [ -x ".tools/bin/$name" ] || {
        printf 'Missing %s; run just init\n' "$name" >&2
        exit 1
    }
    case "$name" in
        gitleaks) output="$(.tools/bin/gitleaks version)" ;;
        *) output="$(".tools/bin/$name" --version)" ;;
    esac
    if ! printf '%s\n' "$output" | grep -Eq "(^|[^0-9.])v?${expected//./\\.}([^0-9.]|$)"; then
        printf 'Wrong %s version; expected %s, found %s\n' "$name" "$expected" "$output" >&2
        exit 1
    fi
done <config/tools.lock.tsv
[ "$(.tools/bin/codespell --version)" = 2.4.3 ]
[ "$(.tools/bin/semgrep --version)" = 1.180.0 ]
[ "$(.tools/python/bin/python --version)" = 'Python 3.14.8' ]
printf '\033[32mEvery required tool is present at its pinned version\033[0m\n'
