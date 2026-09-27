#!/bin/bash
# Install the ai-docs template into the current directory: docs/ and
# ARCHITECTURE.md, plus a Documentation section in AGENTS.md that explains them.

set -euo pipefail

DOCS_DIR="docs"
ARCHITECTURE_FILE="ARCHITECTURE.md"
AGENTS_FILE="AGENTS.md"
CLAUDE_FILE="CLAUDE.md"
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLUEPRINT_PATH="$(cd "$SCRIPT_DIR/.." && pwd)/blueprints/ai-docs"
AGENTS_SECTION="$BLUEPRINT_PATH/agents-section.md"

fail() {
  printf '\033[31m✗ Error: %s\033[0m\n' "$1"
  exit 1
}

warn() {
  printf '\033[33m⚠ %s\033[0m\n' "$1"
}

if [ "$#" -ne 0 ]; then
  printf '\033[31m✗ Error: %s takes no arguments; it installs %s/ and %s in the current directory\033[0m\n' \
    "$SCRIPT_NAME" "$DOCS_DIR" "$ARCHITECTURE_FILE"
  printf 'Usage: %s\n' "$SCRIPT_NAME"
  exit 1
fi

if [ ! -d "$BLUEPRINT_PATH" ]; then
  fail "template not found: $BLUEPRINT_PATH"
fi

if [ ! -f "$AGENTS_SECTION" ]; then
  fail "AGENTS.md section not found: $AGENTS_SECTION"
fi

# Check everything before changing anything, so a refusal leaves no trace.
for path in "$DOCS_DIR" "$ARCHITECTURE_FILE"; do
  if [ -e "$path" ] || [ -L "$path" ]; then
    fail "$PWD/$path already exists; nothing was changed"
  fi
done

# Agent instructions live only in a real AGENTS.md: never in a CLAUDE.md, and
# never behind a symlink, which could also point outside the project.
if [ -e "$CLAUDE_FILE" ] || [ -L "$CLAUDE_FILE" ]; then
  fail "$PWD/$CLAUDE_FILE exists; agent instructions belong in $AGENTS_FILE only. Nothing was changed"
fi

if [ -L "$AGENTS_FILE" ]; then
  fail "$PWD/$AGENTS_FILE is a symlink; nothing was changed"
fi

if [ -e "$AGENTS_FILE" ] && [ ! -f "$AGENTS_FILE" ]; then
  fail "$PWD/$AGENTS_FILE is not a regular file; nothing was changed"
fi

if [ -e "$AGENTS_FILE" ] && [ ! -w "$AGENTS_FILE" ]; then
  fail "$PWD/$AGENTS_FILE is not writable; nothing was changed"
fi

if [ ! -w . ]; then
  fail "$PWD is not writable; nothing was changed"
fi

if ! command -v copier >/dev/null 2>&1; then
  printf '\033[31m✗ Error: copier is not installed\033[0m\n'
  printf 'Install with: pip install copier\n'
  exit 1
fi

work_dir="$(mktemp -d)"
agents_backup="$work_dir/AGENTS.md.orig"
agents_existed=false
if [ -f "$AGENTS_FILE" ]; then
  agents_existed=true
  cp "$AGENTS_FILE" "$agents_backup"
fi
installation_complete=false

# Undo a half-finished installation so that a failed run can simply be retried.
# The checks above proved that docs/ and ARCHITECTURE.md did not exist before.
finish() {
  local status=$?
  if [ "$installation_complete" = false ]; then
    rm -rf "$DOCS_DIR" "$ARCHITECTURE_FILE"
    if [ "$agents_existed" = true ]; then
      if ! cmp -s "$agents_backup" "$AGENTS_FILE"; then
        cat "$agents_backup" > "$AGENTS_FILE"
      fi
    else
      rm -f "$AGENTS_FILE"
    fi
    printf '\033[31m✗ Installation failed; the changes were rolled back\033[0m\n'
  fi
  rm -rf "$work_dir"
  exit "$status"
}
trap finish EXIT

copier copy "$BLUEPRINT_PATH" .
printf '\033[32m✓ Created %s/ and %s in %s\033[0m\n' "$DOCS_DIR" "$ARCHITECTURE_FILE" "$PWD"

if [ -s "$AGENTS_FILE" ]; then
  if [ -n "$(tail -c 1 "$AGENTS_FILE")" ]; then
    printf '\n' >> "$AGENTS_FILE"
  fi
  printf '\n' >> "$AGENTS_FILE"
  cat "$AGENTS_SECTION" >> "$AGENTS_FILE"
  printf '\033[32m✓ Added the Documentation section to %s\033[0m\n' "$AGENTS_FILE"
else
  printf '# AGENTS.md\n\n' > "$AGENTS_FILE"
  cat "$AGENTS_SECTION" >> "$AGENTS_FILE"
  printf '\033[32m✓ Wrote %s with the Documentation section\033[0m\n' "$AGENTS_FILE"
fi
installation_complete=true

if ! command -v git >/dev/null 2>&1; then
  warn "git is not installed; skipped the git-ignore check"
  exit 0
fi

# Read git's answer from stdout only, and tell "not a repository" apart from
# real git failures, which must not silently skip the check.
git_errors="$work_dir/git-errors"
if inside_work_tree="$(LC_ALL=C git rev-parse --is-inside-work-tree 2>"$git_errors")"; then
  if [ "$inside_work_tree" != "true" ]; then
    warn "$PWD is not inside a git work tree; skipped the git-ignore check"
    exit 0
  fi
elif grep -q "not a git repository" "$git_errors"; then
  warn "$PWD is not inside a git work tree; skipped the git-ignore check"
  exit 0
else
  cat "$git_errors"
  fail "git rev-parse failed, so the git-ignore check could not run"
fi

# Check every installed file, not only the directory: patterns such as docs/*
# or *.md ignore all documents while leaving docs itself unmatched.
docs_files="$(find "$DOCS_DIR" -type f)"
if ignored_files="$(printf '%s\n%s\n' "$docs_files" "$ARCHITECTURE_FILE" | git check-ignore --stdin)"; then
  docs_total="$(awk 'END { print NR }' <<< "$docs_files")"
  docs_ignored="$(awk -v prefix="$DOCS_DIR/" 'index($0, prefix) == 1 { count++ } END { print count + 0 }' <<< "$ignored_files")"
  if [ "$docs_ignored" -eq "$docs_total" ]; then
    printf '\033[31m⚠ Warning: %s/ is git-ignored. None of your documentation would ever be committed to git.\033[0m\n' "$DOCS_DIR"
  elif [ "$docs_ignored" -gt 0 ]; then
    printf '\033[31m⚠ Warning: %s of %s files in %s/ are git-ignored and would never be committed to git:\033[0m\n' \
      "$docs_ignored" "$docs_total" "$DOCS_DIR"
    grep "^$DOCS_DIR/" <<< "$ignored_files" | sed 's/^/  /'
  fi
  if grep -qxF "$ARCHITECTURE_FILE" <<< "$ignored_files"; then
    printf '\033[31m⚠ Warning: %s is git-ignored. It would never be committed to git.\033[0m\n' "$ARCHITECTURE_FILE"
  fi
  printf 'Matching ignore rules:\n'
  printf '%s\n' "$ignored_files" | git check-ignore --stdin --verbose | cut -f1 | sort -u | sed 's/^/  /'
  exit 1
else
  check_status=$?
  if [ "$check_status" -ne 1 ]; then
    fail "git check-ignore exited with status $check_status"
  fi
fi

printf '\033[32m✓ %s/ and %s are not git-ignored\033[0m\n' "$DOCS_DIR" "$ARCHITECTURE_FILE"
