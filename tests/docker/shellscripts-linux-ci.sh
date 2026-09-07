#!/usr/bin/env bash
# Runs the shellscripts template's baseline and violation suites in the Linux
# container defined by blueprints/shellscripts-base/docker/Dockerfile.linux-ci.

set -euo pipefail

REPO_ROOT="/repo"
WORK_REPO="/work/ai-guardrails"

if [ ! -d "$REPO_ROOT/blueprints/shellscripts-base" ]; then
    printf '\033[0;31m✗ Error: repo is not mounted at %s\033[0m\n' "$REPO_ROOT"
    exit 1
fi

if [ -e "$WORK_REPO" ]; then
    rm -rf "$WORK_REPO"
fi
cp -a "$REPO_ROOT" "$WORK_REPO"

git config --global --add safe.directory "$WORK_REPO"
git config --global user.email "container-ci@example.invalid"
git config --global user.name "Container CI"
git config --global init.defaultBranch main

cd "$WORK_REPO"

printf '\033[0;34m=== Running shellscripts baseline and violation tests ===\033[0m\n'
./tests/run-tests.sh shellscripts
just test-shellscripts-contracts

printf '\033[0;32m✓ Shell scripts Linux container CI passed\033[0m\n'
