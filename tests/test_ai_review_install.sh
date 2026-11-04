#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALLER="$REPO_ROOT/project-setup/setup-project-ai-review-claude.sh"
README_MARKER='<!-- AI-REVIEW:START -->'
REQUIRED_RECIPES=(ci-ai ci-ai-codex ci-ai-claude ci-ai-grok)
REAL_CP="$(command -v cp)"
REAL_MV="$(command -v mv)"
TEST_ROOT="$(mktemp -d)"
tests_run=0

cleanup() {
  status=$?
  trap - EXIT INT TERM
  if ! rm -rf -- "$TEST_ROOT"; then
    printf 'Failed to remove test directory: %s\n' "$TEST_ROOT" >&2
    status=1
  fi
  exit "$status"
}
trap cleanup EXIT INT TERM

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

new_project() {
  local name="$1"
  local project="$TEST_ROOT/$name"
  mkdir "$project"
  printf '%s\n' "$project"
}

run_installer() {
  local project="$1"
  local expected_status="$2"
  shift 2
  local output="$project/install-output.txt"
  local actual_status
  if (cd "$project" && "$@" "$INSTALLER") >"$output" 2>&1; then
    actual_status=0
  else
    actual_status=$?
  fi
  if [ "$actual_status" -ne "$expected_status" ]; then
    cat "$output" >&2
    fail "installer returned $actual_status, expected $expected_status in $project"
  fi
}

assert_contains() {
  local path="$1"
  local text="$2"
  if ! grep -qF "$text" "$path"; then
    fail "$path does not contain: $text"
  fi
}

assert_absent() {
  local path="$1"
  if [ -e "$path" ] || [ -L "$path" ]; then
    fail "$path unexpectedly exists"
  fi
}

assert_installed_layout() {
  local project="$1"
  for path in scripts/ai-review config/ai-review just/ai-review.just README.md; do
    if [ ! -e "$project/$path" ]; then
      fail "missing installed path: $path"
    fi
  done
  assert_absent "$project/docs/ai-review.md"
  assert_absent "$project/scripts/ai-review/review.py"
  if [ ! -x "$project/scripts/ai-review/review.sh" ]; then
    fail "missing executable installed script: scripts/ai-review/review.sh"
  fi
  if [ ! -f "$project/scripts/ai-review/providers.sh" ]; then
    fail "missing installed provider helper: scripts/ai-review/providers.sh"
  fi
  for config_path in config.json prompts fragments schemas; do
    if [ ! -e "$project/config/ai-review/$config_path" ]; then
      fail "missing installed configuration: config/ai-review/$config_path"
    fi
  done
  assert_contains "$project/README.md" "$README_MARKER"
  jq -e '.providers | keys == ["claude", "codex", "grok"]' "$project/config/ai-review/config.json" >/dev/null ||
    fail "installed configuration does not contain exactly the supported providers"
  local summary
  summary="$(just --justfile "$project/Justfile" --working-directory "$project" --summary)"
  if ! printf '%s\n' "$summary" | jq -Re 'split(" ") | map(select(startswith("ci-ai"))) | sort == ["ci-ai", "ci-ai-claude", "ci-ai-codex", "ci-ai-grok"]' >/dev/null; then
    fail "installed AI review targets do not match the supported providers"
  fi
  for recipe in "${REQUIRED_RECIPES[@]}"; do
    if ! printf '%s\n' "$summary" | tr ' ' '\n' | grep -qxF "$recipe"; then
      fail "missing installed recipe: $recipe"
    fi
  done
  if printf '%s\n' "$summary" | tr ' ' '\n' | grep -qxF ci-ai-help; then
    fail "removed ci-ai-help recipe is still present"
  fi
}

test_installer_is_native_bash() {
  if grep -Eiq '(^|[^[:alnum:]_])(python|uv|copier)([^[:alnum:]_]|$)' "$INSTALLER"; then
    fail "installer depends on Python, uv, or Copier"
  fi
  assert_contains "$INSTALLER" '#!/usr/bin/env bash'
}

test_new_project() {
  local project
  project="$(new_project new-project)"
  run_installer "$project" 0 env
  assert_installed_layout "$project"
  assert_contains "$project/Justfile" '_default:'
  assert_contains "$project/Justfile" '@just help'
  assert_contains "$project/Justfile" '"just ci-ai"'
  local default_output
  default_output="$(just --justfile "$project/Justfile" --working-directory "$project")"
  if [[ "$default_output" != *"just ci-ai"* ]]; then
    fail "new default recipe did not show just ci-ai"
  fi
  local ai_help
  ai_help="$(just --justfile "$project/Justfile" --working-directory "$project" ci-ai)"
  if [[ "$ai_help" != *"codex"* ]] || [[ "$ai_help" != *"security"* ]]; then
    fail "just ci-ai did not show dynamic provider and reviewer help"
  fi
}

test_existing_files_preserve_prefixes_and_default() {
  local project
  project="$(new_project existing-prefixes)"
  printf '_default:\r\n    @printf '\''original\\n'\''\r\n\r\nother:\r\n    @:\r\n' >"$project/Justfile"
  printf '# Existing\r\n\r\nKeep this.\r\n' >"$project/README.md"
  cp "$project/Justfile" "$project/Justfile.before"
  cp "$project/README.md" "$project/README.before"
  local before_default
  before_default="$(just --justfile "$project/Justfile" --working-directory "$project" --show _default)"
  run_installer "$project" 0 env
  local just_size readme_size
  just_size="$(wc -c <"$project/Justfile.before")"
  readme_size="$(wc -c <"$project/README.before")"
  head -c "$just_size" "$project/Justfile" | cmp - "$project/Justfile.before"
  head -c "$readme_size" "$project/README.md" | cmp - "$project/README.before"
  local after_default
  after_default="$(just --justfile "$project/Justfile" --working-directory "$project" --show _default)"
  if [ "$before_default" != "$after_default" ]; then
    fail "existing default recipe changed"
  fi
  assert_installed_layout "$project"
}

test_path_with_spaces_and_case_insensitive_justfile() {
  local project
  project="$(new_project 'project with spaces')"
  printf 'first:\n    @printf '\''first\\n'\''\n' >"$project/.JUSTFILE"
  printf '# Existing\n' >"$project/README.md"
  run_installer "$project" 0 env
  assert_absent "$project/Justfile"
  assert_contains "$project/.JUSTFILE" "import 'just/ai-review.just'"
  just --justfile "$project/.JUSTFILE" --working-directory "$project" --summary >/dev/null
}

test_refuses_collisions_and_markers() {
  local project
  project="$(new_project owned-collision)"
  mkdir -p "$project/scripts/ai-review"
  printf 'keep\n' >"$project/scripts/ai-review/keep"
  run_installer "$project" 1 env
  assert_contains "$project/install-output.txt" 'scripts/ai-review already exists'
  assert_contains "$project/scripts/ai-review/keep" keep

  project="$(new_project repeated-marker)"
  printf '# Existing\n\n%s\n' "$README_MARKER" >"$project/README.md"
  run_installer "$project" 1 env
  assert_contains "$project/install-output.txt" 'already contains the AI review section'
  assert_absent "$project/scripts/ai-review"
}

test_refuses_unsafe_files_and_multiple_justfiles() {
  local shared="$TEST_ROOT/shared"
  printf 'keep\n' >"$shared"
  local project
  project="$(new_project justfile-symlink)"
  ln -s "$shared" "$project/Justfile"
  run_installer "$project" 1 env
  assert_contains "$project/install-output.txt" 'is a symlink'
  assert_contains "$shared" keep

  project="$(new_project readme-symlink)"
  ln -s "$shared" "$project/README.md"
  run_installer "$project" 1 env
  assert_contains "$project/install-output.txt" 'README.md is a symlink'

  project="$(new_project multiple-justfiles)"
  printf 'one:\n    @:\n' >"$project/Justfile"
  printf 'two:\n    @:\n' >"$project/.justfile"
  run_installer "$project" 1 env
  assert_contains "$project/install-output.txt" 'multiple justfiles found'
}

test_refuses_imported_recipes_and_aliases() {
  local project
  project="$(new_project imported-recipe)"
  printf 'set allow-duplicate-recipes\n\nimport '\''existing.just'\''\n' >"$project/Justfile"
  printf 'ci-ai-security:\n    @:\n' >"$project/existing.just"
  printf '# Existing\n' >"$project/README.md"
  cp "$project/Justfile" "$project/Justfile.before"
  run_installer "$project" 1 env
  assert_contains "$project/install-output.txt" 'recipe or alias conflicts'
  cmp "$project/Justfile" "$project/Justfile.before"
  assert_absent "$project/scripts/ai-review"

  project="$(new_project imported-alias)"
  printf 'set allow-duplicate-recipes\n\nimport '\''existing.just'\''\n' >"$project/Justfile"
  printf 'build:\n    @:\n\nalias ci-ai := build\n' >"$project/existing.just"
  printf '# Existing\n' >"$project/README.md"
  run_installer "$project" 1 env
  assert_contains "$project/install-output.txt" 'recipe or alias conflicts'
  assert_absent "$project/config/ai-review"
}

test_repeated_install_is_unchanged() {
  local project
  project="$(new_project repeated-install)"
  run_installer "$project" 0 env
  find "$project" -type f ! -name install-output.txt ! -name before.sha -print0 | sort -z | xargs -0 cksum >"$project/before.sha"
  run_installer "$project" 1 env
  find "$project" -type f ! -name install-output.txt ! -name before.sha ! -name after.sha -print0 | sort -z | xargs -0 cksum >"$project/after.sha"
  cmp "$project/before.sha" "$project/after.sha"
}

test_copy_failure_rolls_back() {
  local project
  project="$(new_project copy-failure)"
  printf '_default:\n    @:\n' >"$project/Justfile"
  printf '# Existing\n' >"$project/README.md"
  mkdir "$project/scripts" "$project/config"
  printf 'keep\n' >"$project/scripts/keep"
  printf 'keep\n' >"$project/config/keep"
  cp "$project/Justfile" "$project/Justfile.before"
  cp "$project/README.md" "$project/README.before"
  local fake_bin="$TEST_ROOT/fake-cp-bin"
  mkdir "$fake_bin"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'set -euo pipefail\n'
    printf 'for argument in "$@"; do\n'
    printf '%s\n' "  case \"\$argument\" in"
    printf '    */blueprints/ai-review/template/config/ai-review) printf "injected cp failure\\n" >&2; exit 19 ;;\n'
    printf '  esac\n'
    printf 'done\n'
    printf 'exec %q "$@"\n' "$REAL_CP"
  } >"$fake_bin/cp"
  chmod +x "$fake_bin/cp"
  run_installer "$project" 1 env PATH="$fake_bin:$PATH"
  assert_contains "$project/install-output.txt" 'injected cp failure'
  assert_contains "$project/install-output.txt" 'changes were rolled back'
  cmp "$project/Justfile" "$project/Justfile.before"
  cmp "$project/README.md" "$project/README.before"
  assert_contains "$project/scripts/keep" keep
  assert_contains "$project/config/keep" keep
  assert_absent "$project/scripts/ai-review"
  assert_absent "$project/config/ai-review"
  assert_absent "$project/just"
}

test_second_file_commit_failure_restores_both_files() {
  local project
  project="$(new_project move-failure)"
  printf '_default:\n    @:\n' >"$project/Justfile"
  printf '# Existing\n' >"$project/README.md"
  cp "$project/Justfile" "$project/Justfile.before"
  cp "$project/README.md" "$project/README.before"
  local fake_bin="$TEST_ROOT/fake-mv-bin"
  mkdir "$fake_bin"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'set -euo pipefail\n'
    printf '%s\n' "if [ \"\${!#}\" = \"README.md\" ]; then printf \"injected mv failure\\n\" >&2; exit 23; fi"
    printf 'exec %q "$@"\n' "$REAL_MV"
  } >"$fake_bin/mv"
  chmod +x "$fake_bin/mv"
  run_installer "$project" 1 env PATH="$fake_bin:$PATH"
  assert_contains "$project/install-output.txt" 'injected mv failure'
  assert_contains "$project/install-output.txt" 'changes were rolled back'
  cmp "$project/Justfile" "$project/Justfile.before"
  cmp "$project/README.md" "$project/README.before"
  assert_absent "$project/scripts/ai-review"
  assert_absent "$project/config/ai-review"
  assert_absent "$project/just/ai-review.just"
}

test_rejects_arguments() {
  local project
  project="$(new_project arguments)"
  local output="$project/install-output.txt"
  local status
  if (cd "$project" && "$INSTALLER" unexpected) >"$output" 2>&1; then
    status=0
  else
    status=$?
  fi
  if [ "$status" -ne 1 ]; then
    fail "argument rejection returned $status"
  fi
  assert_contains "$output" 'takes no arguments'
  assert_absent "$project/Justfile"
}

for test_function in \
  test_installer_is_native_bash \
  test_new_project \
  test_existing_files_preserve_prefixes_and_default \
  test_path_with_spaces_and_case_insensitive_justfile \
  test_refuses_collisions_and_markers \
  test_refuses_unsafe_files_and_multiple_justfiles \
  test_refuses_imported_recipes_and_aliases \
  test_repeated_install_is_unchanged \
  test_copy_failure_rolls_back \
  test_second_file_commit_failure_restores_both_files \
  test_rejects_arguments; do
  "$test_function"
  tests_run=$((tests_run + 1))
  printf 'PASS: %s\n' "$test_function"
done

printf 'AI review installer tests passed: %d\n' "$tests_run"
