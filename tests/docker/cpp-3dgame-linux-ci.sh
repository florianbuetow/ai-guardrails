#!/usr/bin/env bash
# Runs inside the cpp-3dgame-linux-ci container (see
# blueprints/cpp-3dgame-base/docker/Dockerfile.linux-ci): generates a project
# from the mounted repo's template and runs its full CI pipeline.

set -euo pipefail

REPO_ROOT="/repo"
PROJECT_DIR="/work/test-cpp-3dgame-project"

if [ ! -d "$REPO_ROOT/blueprints/cpp-3dgame-base" ]; then
    printf '\033[0;31m✗ Error: repo not mounted at /repo\033[0m\n'
    exit 1
fi

# The mounted repo belongs to a different uid; git (used by copier) must
# trust it explicitly.
git config --global --add safe.directory "$REPO_ROOT"
git config --global user.email "container-ci@example.invalid"
git config --global user.name "Container CI"
git config --global init.defaultBranch main

printf '\033[0;34m=== Generating project from template (Linux container) ===\033[0m\n'
rm -rf "$PROJECT_DIR"
copier copy --trust --defaults \
    --data project_name=test-cpp-3dgame-project \
    --data "project_description=Linux container CI project" \
    --data cpp_standard=23 \
    --data "author_name=Container CI" \
    --data author_email=container-ci@example.invalid \
    --data coverage_threshold=80 \
    "$REPO_ROOT/blueprints/cpp-3dgame-base" "$PROJECT_DIR"

cd "$PROJECT_DIR"
git init -q
git add -A
git -c advice.ignoredHook=false commit -qm "container ci init"

printf '\033[0;34m=== Running full CI inside the container ===\033[0m\n'
just ci

printf '\033[0;32m✓ Linux container CI passed\033[0m\n'
