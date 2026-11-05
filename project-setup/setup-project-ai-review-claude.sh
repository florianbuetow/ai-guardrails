#!/usr/bin/env bash
# Add the language-independent AI review commands to the current project.

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLUEPRINT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)/blueprints/ai-review"
TEMPLATE_DIR="$BLUEPRINT_DIR/template"
README_SECTION="$BLUEPRINT_DIR/README-section.md"
README_MARKER='<!-- AI-REVIEW:START -->'
IMPORT_LINE="import 'config/ai-review/ai-review.just'"
OWNED_PATHS=(scripts/ai-review config/ai-review)

fail() {
  printf '\033[31m✗ Error: %s\033[0m\n' "$1" >&2
  exit 1
}

if [ "$#" -ne 0 ]; then
  printf '\033[31m✗ Error: %s takes no arguments; it installs AI review support in the current directory\033[0m\n' "$SCRIPT_NAME" >&2
  printf 'Usage: %s\n' "$SCRIPT_NAME" >&2
  exit 1
fi

for required_command in cp find jq just mktemp mv; do
  if ! command -v "$required_command" >/dev/null 2>&1; then
    fail "$required_command is required but was not found on PATH; nothing was changed"
  fi
done

if [ ! -d "$TEMPLATE_DIR" ]; then
  fail "template not found: $TEMPLATE_DIR"
fi
if [ ! -f "$README_SECTION" ] || [ -L "$README_SECTION" ]; then
  fail "README section not found or unsafe: $README_SECTION"
fi
if ! grep -qF "$README_MARKER" "$README_SECTION"; then
  fail "README section is missing its installation marker: $README_MARKER"
fi

justfiles=()
while IFS= read -r -d '' candidate; do
  justfiles+=("$candidate")
done < <(find . -maxdepth 1 \( -iname 'justfile' -o -iname '.justfile' \) -print0)

if [ "${#justfiles[@]}" -gt 1 ]; then
  names=""
  for candidate in "${justfiles[@]}"; do
    names="${names}${names:+, }${candidate#./}"
  done
  fail "multiple justfiles found ($names); nothing was changed"
fi

justfile="Justfile"
justfile_existed=false
if [ "${#justfiles[@]}" -eq 1 ]; then
  justfile="${justfiles[0]#./}"
  justfile_existed=true
  if [ -L "$justfile" ]; then
    fail "$justfile is a symlink; nothing was changed"
  fi
  if [ ! -f "$justfile" ]; then
    fail "$justfile is not a regular file; nothing was changed"
  fi
  if [ ! -w "$justfile" ]; then
    fail "$justfile is not writable; nothing was changed"
  fi
fi

readme="README.md"
readme_existed=false
if [ -e "$readme" ] || [ -L "$readme" ]; then
  readme_existed=true
  if [ -L "$readme" ]; then
    fail "$readme is a symlink; nothing was changed"
  fi
  if [ ! -f "$readme" ]; then
    fail "$readme is not a regular file; nothing was changed"
  fi
  if [ ! -w "$readme" ]; then
    fail "$readme is not writable; nothing was changed"
  fi
  if grep -qF "$README_MARKER" "$readme"; then
    fail "$readme already contains the AI review section; nothing was changed"
  fi
fi

for relative_path in "${OWNED_PATHS[@]}"; do
  destination="$PWD/$relative_path"
  if [ -e "$destination" ] || [ -L "$destination" ]; then
    fail "$relative_path already exists; nothing was changed"
  fi
  parent="$PWD"
  remaining="${relative_path%/*}"
  while [ "$remaining" != "." ] && [ -n "$remaining" ]; do
    component="${remaining%%/*}"
    parent="$parent/$component"
    if [ -L "$parent" ]; then
      fail "${parent#"$PWD/"} is a symlink; nothing was changed"
    fi
    if [ -e "$parent" ] && [ ! -d "$parent" ]; then
      fail "${parent#"$PWD/"} is not a directory; nothing was changed"
    fi
    if [ "$remaining" = "$component" ]; then
      break
    fi
    remaining="${remaining#*/}"
  done
  source_path="$TEMPLATE_DIR/$relative_path"
  if [ ! -e "$source_path" ] || [ -L "$source_path" ]; then
    fail "template path is missing or unsafe: $source_path"
  fi
  if [ -n "$(find "$source_path" -type l -print -quit)" ]; then
    fail "template path contains a symlink: $source_path"
  fi
done

work_dir="$(mktemp -d)"
just_backup="$work_dir/justfile.original"
readme_backup="$work_dir/README.md.original"
just_candidate=""
readme_candidate=""
created_paths=()
installation_complete=false
just_backed_up=false
readme_backed_up=false

rollback() {
  status=$?
  trap - EXIT INT TERM
  cleanup_failed=false
  if [ "$installation_complete" = false ]; then
    if [ "$justfile_existed" = true ]; then
      if [ "$just_backed_up" = true ]; then
        if ! cp -p "$just_backup" "$justfile"; then
          printf '\033[31m✗ Failed to restore %s\033[0m\n' "$justfile" >&2
          cleanup_failed=true
        fi
      fi
    elif [ -e "$justfile" ] || [ -L "$justfile" ]; then
      if ! rm -f -- "$justfile"; then
        printf '\033[31m✗ Failed to remove new %s\033[0m\n' "$justfile" >&2
        cleanup_failed=true
      fi
    fi
    if [ "$readme_existed" = true ]; then
      if [ "$readme_backed_up" = true ]; then
        if ! cp -p "$readme_backup" "$readme"; then
          printf '\033[31m✗ Failed to restore %s\033[0m\n' "$readme" >&2
          cleanup_failed=true
        fi
      fi
    elif [ -e "$readme" ] || [ -L "$readme" ]; then
      if ! rm -f -- "$readme"; then
        printf '\033[31m✗ Failed to remove new %s\033[0m\n' "$readme" >&2
        cleanup_failed=true
      fi
    fi
    index=$((${#created_paths[@]} - 1))
    while [ "$index" -ge 0 ]; do
      if [ -e "${created_paths[$index]}" ] || [ -L "${created_paths[$index]}" ]; then
        if ! rm -rf -- "${created_paths[$index]}"; then
          printf '\033[31m✗ Failed to remove %s during rollback\033[0m\n' "${created_paths[$index]}" >&2
          cleanup_failed=true
        fi
      fi
      index=$((index - 1))
    done
    if [ "$cleanup_failed" = false ]; then
      printf '\033[31m✗ Installation failed; changes were rolled back\033[0m\n' >&2
    fi
    status=1
  fi
  if ! rm -rf -- "$work_dir"; then
    printf '\033[31m✗ Failed to remove installer temporary directory: %s\033[0m\n' "$work_dir" >&2
    status=1
  fi
  exit "$status"
}
trap rollback EXIT INT TERM

if [ "$justfile_existed" = true ]; then
  cp -p "$justfile" "$just_backup"
  just_backed_up=true
  if ! just --justfile "$PWD/$justfile" --working-directory "$PWD" --json >"$work_dir/just.json"; then
    fail "the existing justfile is invalid; nothing was changed"
  fi
  if ! jq -e '(.recipes | type == "object") and (.aliases | type == "object")' "$work_dir/just.json" >/dev/null; then
    fail "just returned an invalid recipe manifest; nothing was changed"
  fi
  conflicts="$(jq -r '[.recipes, .aliases] | map(keys[]) | .[] | select(. == "ci-ai" or startswith("ci-ai-"))' "$work_dir/just.json")"
  if [ -n "$conflicts" ]; then
    fail "existing AI review recipe or alias conflicts with this installer: $(printf '%s' "$conflicts" | tr '\n' ' '); nothing was changed"
  fi
fi

if [ "$readme_existed" = true ]; then
  cp -p "$readme" "$readme_backup"
  readme_backed_up=true
fi

just_candidate="$(mktemp "$PWD/.ai-review-justfile.XXXXXX")"
created_paths+=("$just_candidate")
readme_candidate="$(mktemp "$PWD/.ai-review-readme.XXXXXX")"
created_paths+=("$readme_candidate")

make_parent() {
  local relative_path="$1"
  local parent_path="${relative_path%/*}"
  local current="$PWD"
  local component
  local remaining="$parent_path"
  while [ "$remaining" != "." ] && [ -n "$remaining" ]; do
    component="${remaining%%/*}"
    current="$current/$component"
    if [ ! -d "$current" ]; then
      mkdir "$current"
      created_paths+=("$current")
    fi
    if [ "$remaining" = "$component" ]; then
      break
    fi
    remaining="${remaining#*/}"
  done
}

for relative_path in "${OWNED_PATHS[@]}"; do
  make_parent "$relative_path"
  destination="$PWD/$relative_path"
  created_paths+=("$destination")
  cp -R "$TEMPLATE_DIR/$relative_path" "$destination"
done

if [ "$justfile_existed" = true ]; then
  cp -p "$just_backup" "$just_candidate"
  if [ -s "$just_candidate" ]; then
    if [ -n "$(tail -c 1 "$just_candidate")" ]; then
      printf '\n' >>"$just_candidate"
    fi
    printf '\n' >>"$just_candidate"
  fi
else
  {
    printf '_default:\n'
    printf '    @just help\n\n'
    printf 'help:\n'
    printf '    @echo ""\n'
    printf '    @printf "AI review commands:\\n"\n'
    printf '    @printf "  %%s\\n" "just ci-ai"\n'
    printf '    @echo ""\n'
    printf '    @printf "\\033[32m✓ Help displayed\\033[0m\\n"\n'
    printf '    @echo ""\n\n'
  } >"$just_candidate"
  chmod 644 "$just_candidate"
fi
printf "%s\n%s\n" "# AI review commands: run \`just ci-ai\` for dynamic help." "$IMPORT_LINE" >>"$just_candidate"

if [ "$readme_existed" = true ]; then
  cp -p "$readme_backup" "$readme_candidate"
  if [ -s "$readme_candidate" ]; then
    if [ -n "$(tail -c 1 "$readme_candidate")" ]; then
      printf '\n' >>"$readme_candidate"
    fi
    printf '\n' >>"$readme_candidate"
  fi
else
  printf '# README\n\n' >"$readme_candidate"
  chmod 644 "$readme_candidate"
fi
cp "$README_SECTION" "$work_dir/README-section.md"
cat "$work_dir/README-section.md" >>"$readme_candidate"

if ! just --justfile "$just_candidate" --working-directory "$PWD" --summary >"$work_dir/summary"; then
  fail "the resulting justfile is invalid"
fi
for required_recipe in ci-ai ci-ai-codex ci-ai-claude ci-ai-grok; do
  if ! tr ' ' '\n' <"$work_dir/summary" | grep -qxF "$required_recipe"; then
    fail "the resulting justfile does not expose required recipe: $required_recipe"
  fi
done
if tr ' ' '\n' <"$work_dir/summary" | grep -qxF 'ci-ai-help'; then
  fail "the resulting justfile unexpectedly exposes removed recipe: ci-ai-help"
fi

mv "$just_candidate" "$justfile"
mv "$readme_candidate" "$readme"
installation_complete=true

printf '\033[32m✓ Installed AI review commands in %s\033[0m\n' "$PWD"
printf "%s\n" "Run \`just ci-ai\` to list providers and review domains."
