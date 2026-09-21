#!/bin/sh
set -eu
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    git init -q
fi
hook_dir=$(git rev-parse --git-path hooks)
mkdir -p "$hook_dir"
printf '%s\n' '#!/bin/sh' 'set -eu' 'just ci-quiet' > "$hook_dir/pre-commit"
chmod +x "$hook_dir/pre-commit"
