#!/bin/bash
set -euo pipefail

# shellcheck source=environment.sh
source scripts/environment.sh
# Include owned root files and untracked source. Git's ignore rules exclude only
# generated projects, build outputs and downloaded dependencies in this template.
git ls-files --cached --others --exclude-standard -z >build/reports/owned-files.zlist
: >build/reports/empty-gitleaksignore
.tools/bin/gitleaks git --staged --config .gitleaks.toml --redact --no-banner \
    --log-level warn --ignore-gitleaks-allow \
    --gitleaks-ignore-path build/reports/empty-gitleaksignore
count=0
while IFS= read -r -d '' path; do
    if [ ! -e "$path" ] && [ ! -L "$path" ]; then
        deleted="$(git ls-files --deleted -- "$path")"
        if [ "$deleted" = "$path" ]; then
            continue
        fi
    fi
    if [ ! -f "$path" ] || [ -L "$path" ]; then
        printf 'Cannot scan non-regular project file: %s\n' "$path" >&2
        exit 1
    fi
    .tools/bin/gitleaks dir "$path" --config .gitleaks.toml --redact --no-banner \
        --log-level warn --ignore-gitleaks-allow \
        --gitleaks-ignore-path build/reports/empty-gitleaksignore
    count=$((count + 1))
done <build/reports/owned-files.zlist
if [ "$count" -eq 0 ]; then
    printf 'No project-owned files were scanned\n' >&2
    exit 1
fi
printf '\033[32mScanned %s owned files for secrets\033[0m\n' "$count"
