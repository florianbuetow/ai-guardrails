#!/usr/bin/env bash
# Launch independent reviewers and verifiers; investigation belongs to the agents.
set -euo pipefail
set -m

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
CONFIG_DIR="$PROJECT_ROOT/config/ai-review"
CONFIG="$CONFIG_DIR/config.json"
RUN_DIR=""
JOB_PIDS=()
WATCH_PIDS=()
JOB_LABELS=()
JOB_TIMEOUTS=()

fail() {
  printf '\033[31mAI review: %s\033[0m\n' "$*" >&2
  exit 1
}
stop_group() {
  local group=$1 attempt
  if kill -0 -- "-$group" 2>/dev/null; then
    if ! kill -TERM -- "-$group" 2>/dev/null; then
      if kill -0 -- "-$group" 2>/dev/null; then return 1; fi
    fi
    for ((attempt = 0; attempt < 5; attempt++)); do
      if ! kill -0 -- "-$group" 2>/dev/null; then return 0; fi
      sleep 0.1
    done
    if kill -0 -- "-$group" 2>/dev/null; then
      if ! kill -KILL -- "-$group" 2>/dev/null; then
        if kill -0 -- "-$group" 2>/dev/null; then return 1; fi
      fi
    fi
  fi
}

cleanup() {
  local status=$? pid
  trap - EXIT INT TERM
  for pid in ${WATCH_PIDS[@]+"${WATCH_PIDS[@]}"} ${JOB_PIDS[@]+"${JOB_PIDS[@]}"}; do
    [ -n "$pid" ] || continue
    if ! stop_group "$pid"; then status=1; fi
  done
  if [ "$status" -ne 0 ] && [ -n "$RUN_DIR" ] && [ ! -f "$RUN_DIR/report.json" ]; then
    printf '{"complete":false,"error":"Review execution or verification failed; inspect session logs."}\n' >"$RUN_DIR/report.json"
    printf 'Incomplete review report: %s/report.json\n' "$RUN_DIR" >&2
  fi
  exit "$status"
}
trap cleanup EXIT
trap 'exit 1' INT TERM

for tool in jq git; do command -v "$tool" >/dev/null || fail "Required command missing: $tool"; done
[ -f "$CONFIG" ] || fail "Missing config: $CONFIG"
jq -e '
  (.providers | type == "object" and length > 0) and
  (.providers | keys | all(. == "claude" or . == "codex" or . == "grok")) and
  (.providers | all(.[]; (.model | type == "string"))) and
  (.agents | type == "array" and length > 0) and
  (all(.agents[]; (.name | type == "string" and test("^[a-z][a-z0-9-]*$")) and
    (.prompt | type == "string" and test("^[a-zA-Z0-9_-]+\\.md$")) and
    (.description | type == "string") and (.enabled | type == "boolean"))) and
  ([.agents[].name] | length == (unique | length)) and
  (.verifier.prompt | type == "string" and test("^[a-zA-Z0-9_-]+\\.md$")) and
  (.timeout_seconds | type == "number" and . > 0 and . == floor) and
  (.report_directory | type == "string" and length > 0)
' "$CONFIG" >/dev/null || fail "Invalid configuration"

show_help() {
  local provider=${1:-}
  if [ -n "$provider" ]; then
    printf 'Usage:\n  just ci-ai-%s <diff|commit|global> [agent] [commit-hash]\n\n' "$provider"
  else
    printf 'AI review\n\nUsage:\n  just ci-ai\n  just ci-ai-<provider> <diff|commit|global> [agent] [commit-hash]\n\n'
  fi
  printf 'Scopes:\n  diff    uncommitted changes\n  commit  one commit (HEAD unless a hash is given)\n  global  the whole project\n\n'
  if [ -z "$provider" ]; then
    printf 'Providers:\n'
    jq -r '.providers | to_entries[] | "  " + .key + (if .value | has("description") then " — " + .value.description else "" end)' "$CONFIG"
    printf '\n'
  fi
  printf 'Agents (default: all enabled):\n'
  jq -r '.agents[] | "  " + .name + " — " + .description + (if .enabled then "" else " (disabled)" end)' "$CONFIG"
  local p=${provider:-codex}
  printf '\nExamples:\n  just ci-ai-%s diff\n  just ci-ai-%s global specs-review\n  just ci-ai-%s commit security abc123\n  just ci-ai-%s commit "" abc123\n\n' "$p" "$p" "$p" "$p"
  printf 'Only commit scope accepts a hash.\n'
}
[ "$#" -gt 0 ] || fail "Expected help or run"
if [ "$1" = help ]; then
  [ "$#" -le 2 ] || fail "help takes at most one provider"
  show_help "${2:-}"
  exit 0
fi
[ "$1" = run ] || fail "Expected help or run"
[ "$#" -ge 3 ] && [ "$#" -le 5 ] || fail "Usage: run PROVIDER SCOPE [AGENT] [HASH]"
PROVIDER=$2
SCOPE=$3
AGENT=""
REVISION=""
if [ "$#" -ge 4 ]; then AGENT=$4; fi
if [ "$#" -eq 5 ]; then REVISION=$5; fi
case "$SCOPE" in diff | commit | global) ;; *) fail "Unknown scope: $SCOPE" ;; esac
[ "$SCOPE" = commit ] || [ -z "$REVISION" ] || fail "A hash is only valid for commit scope"
jq -e --arg p "$PROVIDER" '.providers | has($p)' "$CONFIG" >/dev/null || fail "Unknown provider: $PROVIDER"
MODEL="$(jq -er --arg p "$PROVIDER" '.providers[$p].model | select(test("\\S"))' "$CONFIG")" || fail "Configure an explicit model for $PROVIDER"
command -v "$PROVIDER" >/dev/null || fail "Required CLI missing: $PROVIDER"
if [ -n "$AGENT" ]; then
  jq -e --arg a "$AGENT" 'any(.agents[]; .name == $a and .enabled)' "$CONFIG" >/dev/null || {
    show_help
    fail "Unknown or disabled agent: $AGENT"
  }
  SELECTED="$(jq -c --arg a "$AGENT" '[.agents[] | select(.name == $a and .enabled)]' "$CONFIG")"
else
  SELECTED="$(jq -c '[.agents[] | select(.enabled)]' "$CONFIG")"
fi
[ "$(jq length <<<"$SELECTED")" -gt 0 ] || fail "No enabled reviewers"
[ "$(git -C "$PROJECT_ROOT" rev-parse --show-toplevel)" = "$PROJECT_ROOT" ] || fail "Install at the Git repository root"
TIMEOUT="$(jq -r .timeout_seconds "$CONFIG")"
REPORT_ROOT="$(jq -r .report_directory "$CONFIG")"
case "$REPORT_ROOT" in /*) ;; *) REPORT_ROOT="$PROJECT_ROOT/$REPORT_ROOT" ;; esac
[ -d "$REPORT_ROOT" ] || fail "Report directory does not exist: $REPORT_ROOT"
RUN_DIR="$(mktemp -d "$REPORT_ROOT/ai-review.XXXXXX")"
printf 'Review artifacts: %s\n' "$RUN_DIR"
mkdir "$RUN_DIR/prompts" "$RUN_DIR/reviews" "$RUN_DIR/verifications"
[ -n "${HOME-}" ] || fail "HOME is required for Markdown reports"
MARKDOWN_ROOT="$HOME/reports/ai-review"
[ ! -L "$HOME/reports" ] && [ ! -L "$MARKDOWN_ROOT" ] || fail "Report directories must not be symlinks"
mkdir -p "$MARKDOWN_ROOT"
REPORT_TIMESTAMP="$(date +%Y%m%d%H%M%S)"
RUN_ID=${RUN_DIR##*/}
WORKSPACE="$PROJECT_ROOT"
BASE=""
COMMIT=""
if [ "$SCOPE" = commit ]; then
  if [ -z "$REVISION" ]; then REVISION=HEAD; fi
  COMMIT="$(git -C "$PROJECT_ROOT" rev-parse --verify --end-of-options "$REVISION^{commit}")"
  parents="$(git -C "$PROJECT_ROOT" rev-list --parents -n 1 "$COMMIT")"
  if [[ "$parents" == *' '* ]]; then
    BASE="${parents#* }"
    BASE="${BASE%% *}"
    git -C "$PROJECT_ROOT" diff --no-ext-diff --no-textconv "$BASE" "$COMMIT" -- >"$RUN_DIR/diff.patch"
    git -C "$PROJECT_ROOT" diff --name-only -z "$BASE" "$COMMIT" -- >"$RUN_DIR/files.bin"
  else
    git -C "$PROJECT_ROOT" diff-tree --root --no-commit-id -p --no-ext-diff --no-textconv "$COMMIT" -- >"$RUN_DIR/diff.patch"
    git -C "$PROJECT_ROOT" diff-tree --root --no-commit-id --name-only -r -z "$COMMIT" -- >"$RUN_DIR/files.bin"
  fi
  # Supply a filesystem for the requested historical revision, not current HEAD.
  WORKSPACE="$RUN_DIR/commit-workspace"
  mkdir "$WORKSPACE"
  git -C "$PROJECT_ROOT" ls-tree -r -z "$COMMIT" >"$RUN_DIR/tree.bin"
  while IFS= read -r -d '' entry; do
    metadata=${entry%%$'\t'*}
    path=${entry#*$'\t'}
    read -r mode type object <<<"$metadata"
    [ "$type" = blob ] && [ "$mode" != 120000 ] || fail "Commit scope does not support symlinks or submodules: $path"
    case "/$path/" in */../* | */./*) fail "Unsafe Git tree path: $path" ;; esac
    case "$path" in /* | .git | .git/*) fail "Unsafe Git tree path: $path" ;; esac
    mkdir -p "$(dirname "$WORKSPACE/$path")"
    git -C "$PROJECT_ROOT" cat-file blob "$object" >"$WORKSPACE/$path"
    if [ "$mode" = 100755 ]; then chmod 755 "$WORKSPACE/$path"; fi
  done <"$RUN_DIR/tree.bin"
elif [ "$SCOPE" = diff ]; then
  COMMIT="$(git -C "$PROJECT_ROOT" rev-parse --verify HEAD)"
  BASE=$COMMIT
  git -C "$PROJECT_ROOT" diff --no-ext-diff --no-textconv HEAD -- >"$RUN_DIR/diff.patch"
  git -C "$PROJECT_ROOT" diff --name-only -z HEAD -- >"$RUN_DIR/files.bin"
  git -C "$PROJECT_ROOT" ls-files --others --exclude-standard -z >>"$RUN_DIR/files.bin"
else
  git -C "$PROJECT_ROOT" ls-files --cached --others --exclude-standard -z >"$RUN_DIR/files.bin"
  : >"$RUN_DIR/diff.patch"
fi
jq -Rs 'split("\u0000") | map(select(length > 0)) | unique' "$RUN_DIR/files.bin" >"$RUN_DIR/files.json"
[ "$(jq length "$RUN_DIR/files.json")" -gt 0 ] || fail "No files in selected scope"
jq -n --arg workspace "$WORKSPACE" --arg scope "$SCOPE" --arg commit "$COMMIT" --arg base "$BASE" \
  --arg diff_path "$RUN_DIR/diff.patch" --rawfile diff "$RUN_DIR/diff.patch" --slurpfile files "$RUN_DIR/files.json" \
  '{workspace:$workspace,scope:$scope,commit:$commit,base:$base,files:$files[0],diff_path:$diff_path,diff:$diff}' >"$RUN_DIR/scope.json"

render_prompt() {
  local file=$1 stack=$2 line token name dependency found replacement
  case "$stack" in *"|$file|"*) fail "Circular prompt include: $file" ;; esac
  [ -f "$file" ] && [ ! -L "$file" ] || fail "Missing or symlinked prompt: $file"
  while IFS= read -r line || [ -n "$line" ]; do
    while [[ "$line" =~ \{\{([A-Za-z0-9_-]+)\}\} ]]; do
      token=${BASH_REMATCH[0]}
      name=${BASH_REMATCH[1]}
      found=0
      dependency=""
      for candidate in "$CONFIG_DIR/fragments/$name.md" "$CONFIG_DIR/prompts/$name.md"; do
        if [ -f "$candidate" ]; then
          dependency=$candidate
          found=$((found + 1))
        fi
      done
      [ "$found" -eq 1 ] || fail "Missing or ambiguous prompt include: $name"
      replacement="$(render_prompt "$dependency" "$stack|$file|")" || return 1
      line=${line/"$token"/"$replacement"}
    done
    [[ "$line" != *'{{'* ]] || fail "Invalid template reference in $file"
    printf '%s\n' "$line"
  done <"$file"
}

# Load backend functions without executing any provider at source time.
source "$SCRIPT_DIR/providers.sh"

validate_review() {
  jq -e '
    def nonempty: type == "string" and test("\\S");
    def severity: . == "low" or . == "medium" or . == "high";
    type == "object" and keys == ["complete","findings","warnings"] and .complete == true and
    (.warnings | type == "array" and all(.[]; type == "string")) and
    (.findings | type == "array" and all(.[];
      type == "object" and keys == ["basis","description","evidence","file","line","severity","title"] and
      (.severity | severity) and (.file | nonempty and (test("[\u0000-\u001f]") | not) and (startswith("/") | not) and (split("/") | all(. != ".."))) and
      (.line | type == "number" and . >= 1 and . == floor) and
      ([.title,.description,.evidence,.basis] | all(.[]; nonempty))))
  ' "$1" >/dev/null
}
validate_verification() {
  jq -e --slurpfile candidates "$2" '
    def nonempty: type == "string" and test("\\S");
    type == "object" and keys == ["complete","verdicts","warnings"] and .complete == true and
    (.warnings | type == "array" and all(.[]; type == "string")) and
    (.verdicts | type == "array" and all(.[];
      keys == ["basis","id","reason","severity","status"] and
      (.status == "confirmed" or .status == "rejected") and
      (.severity == "low" or .severity == "medium" or .severity == "high") and
      ([.id,.reason,.basis] | all(.[]; nonempty)))) and
    ([.verdicts[].id] | sort) == ([$candidates[0][].id] | sort)
  ' "$1" >/dev/null
}

validate_locations() {
  local finding file line count path component
  while IFS= read -r finding; do
    file=$(jq -r .file <<<"$finding")
    line=$(jq -r .line <<<"$finding")
    path=$WORKSPACE
    local components=()
    IFS=/ read -r -a components <<<"$file"
    for component in "${components[@]}"; do
      [ -n "$component" ] && [ "$component" != . ] && [ "$component" != .. ] || return 1
      path="$path/$component"
      [ ! -L "$path" ] || return 1
    done
    if [ -f "$path" ]; then
      count=$(awk 'END { print NR }' "$path")
    elif [ -n "$BASE" ] && [ "$SCOPE" != global ]; then
      git -C "$PROJECT_ROOT" show "$BASE:$file" >"$(dirname "$1")/location.txt"
      count=$(awk 'END { print NR }' "$(dirname "$1")/location.txt")
    else
      printf 'Finding refers to nonexistent file: %s\n' "$file" >&2
      return 1
    fi
    [ "$line" -le "$count" ] || {
      printf 'Finding line is out of bounds: %s:%s\n' "$file" "$line" >&2
      return 1
    }
  done < <(jq -c '.findings[]' "$1")
}

run_session() {
  local phase=$1 name=$2 prompt=$3 schema=$4 input=$5 directory report_path
  directory="$RUN_DIR/$phase/$name"
  mkdir "$directory"
  report_path="$MARKDOWN_ROOT/${REPORT_TIMESTAMP}_${PROVIDER}_${phase}_${name}_${RUN_ID}.md"
  [ ! -e "$report_path" ] && [ ! -L "$report_path" ] || {
    printf 'Report already exists: %s\n' "$report_path" >&2
    return 1
  }
  provider_launch "$PROVIDER" "$MODEL" "$WORKSPACE" "$prompt" "$schema" "$directory" "$report_path"
  provider_decode "$PROVIDER" "$directory" >"$directory/result.json"
  jq -e -s 'length == 1' "$directory/result.json" >/dev/null
  [ -s "$report_path" ] && [ ! -L "$report_path" ] || {
    printf 'Agent did not write its Markdown report: %s\n' "$report_path" >&2
    return 1
  }
  if [ "$phase" = reviews ]; then
    validate_review "$directory/result.json"
    validate_locations "$directory/result.json"
  else
    validate_verification "$directory/result.json" "$input"
  fi
}
launch_session() {
  local phase=$1 name=$2 prompt=$3 schema=$4 input=$5 pid
  printf 'Starting %s: %s\n' "$phase" "$name"
  jq -cn --arg phase "$phase" --arg agent "$name" \
    --arg path "$MARKDOWN_ROOT/${REPORT_TIMESTAMP}_${PROVIDER}_${phase}_${name}_${RUN_ID}.md" \
    '{phase:$phase,agent:$agent,path:$path}' >>"$RUN_DIR/markdown-reports.jsonl"
  run_session "$phase" "$name" "$prompt" "$schema" "$input" >"$RUN_DIR/$phase/$name.log" 2>&1 &
  pid=$!
  JOB_PIDS+=("$pid")
  JOB_LABELS+=("$phase/$name")
  JOB_TIMEOUTS+=("$RUN_DIR/$phase/$name.timeout")
  (
    sleep "$TIMEOUT"
    if kill -0 "$pid" 2>/dev/null; then
      printf 'Timed out: %s/%s\n' "$phase" "$name" >"$RUN_DIR/$phase/$name.timeout"
      stop_group "$pid"
    fi
  ) &
  WATCH_PIDS+=("$!")
}
wait_sessions() {
  local i pid remaining=${#JOB_PIDS[@]} failed watchdog_status
  while [ "$remaining" -gt 0 ]; do
    for i in "${!JOB_PIDS[@]}"; do
      pid=${JOB_PIDS[$i]}
      [ -n "$pid" ] || continue
      if ! kill -0 "$pid" 2>/dev/null; then
        failed=0
        if wait "$pid"; then :; else failed=1; fi
        if [ -f "${JOB_TIMEOUTS[$i]}" ]; then failed=1; fi
        stop_group "$pid"
        stop_group "${WATCH_PIDS[$i]}"
        if wait "${WATCH_PIDS[$i]}" 2>/dev/null; then
          watchdog_status=0
        else
          watchdog_status=$?
        fi
        case "$watchdog_status" in 0 | 137 | 143) ;; *) failed=1 ;; esac
        JOB_PIDS[i]=""
        WATCH_PIDS[i]=""
        remaining=$((remaining - 1))
        [ "$failed" -eq 0 ] || fail "Session ${JOB_LABELS[$i]} failed; inspect $RUN_DIR/${JOB_LABELS[$i]}.log and session stderr"
      fi
    done
    if [ "$remaining" -gt 0 ]; then sleep 0.1; fi
  done
  JOB_PIDS=()
  WATCH_PIDS=()
  JOB_LABELS=()
  JOB_TIMEOUTS=()
}

# Render every prompt before starting any paid CLI session.
while IFS= read -r agent; do
  name="$(jq -r .name <<<"$agent")"
  filename="$(jq -r .prompt <<<"$agent")"
  render_prompt "$CONFIG_DIR/prompts/$filename" "" >"$RUN_DIR/prompts/$name.md"
  printf '\nREVIEW_INPUT_JSON\n' >>"$RUN_DIR/prompts/$name.md"
  jq --arg agent "$name" --arg report_path "$MARKDOWN_ROOT/${REPORT_TIMESTAMP}_${PROVIDER}_reviews_${name}_${RUN_ID}.md" '. + {agent:$agent,report_path:$report_path}' "$RUN_DIR/scope.json" >>"$RUN_DIR/prompts/$name.md"
done < <(jq -c '.[]' <<<"$SELECTED")
VERIFIER_FILE="$(jq -r .verifier.prompt "$CONFIG")"
render_prompt "$CONFIG_DIR/prompts/$VERIFIER_FILE" "" >"$RUN_DIR/prompts/verifier-base.md"
while IFS= read -r name; do
  launch_session reviews "$name" "$RUN_DIR/prompts/$name.md" "$CONFIG_DIR/schemas/findings.json" ""
done < <(jq -r '.[].name' <<<"$SELECTED")
wait_sessions

CANDIDATE_FILES=()
while IFS= read -r name; do
  candidate_file="$RUN_DIR/reviews/$name/candidates.json"
  jq --arg name "$name" '[.findings | to_entries[] | .value + {id:($name + "-" + (.key|tostring)),agent:$name}]' \
    "$RUN_DIR/reviews/$name/result.json" >"$candidate_file"
  CANDIDATE_FILES+=("$candidate_file")
  if [ "$(jq length "$candidate_file")" -gt 0 ]; then
    cp "$RUN_DIR/prompts/verifier-base.md" "$RUN_DIR/prompts/verify-$name.md"
    printf '\nREVIEW_INPUT_JSON\n' >>"$RUN_DIR/prompts/verify-$name.md"
    jq --arg agent "$name" --arg report_path "$MARKDOWN_ROOT/${REPORT_TIMESTAMP}_${PROVIDER}_verifications_${name}_${RUN_ID}.md" --slurpfile candidates "$candidate_file" '. + {agent:$agent,report_path:$report_path,candidates:$candidates[0]}' \
      "$RUN_DIR/scope.json" >>"$RUN_DIR/prompts/verify-$name.md"
    launch_session verifications "$name" "$RUN_DIR/prompts/verify-$name.md" "$CONFIG_DIR/schemas/verification.json" "$candidate_file"
  fi
done < <(jq -r '.[].name' <<<"$SELECTED")
if [ "${#JOB_PIDS[@]}" -gt 0 ]; then wait_sessions; fi
jq -s 'add' "${CANDIDATE_FILES[@]}" >"$RUN_DIR/candidates.json"
printf '[]\n' >"$RUN_DIR/verdicts.json"
printf '[]\n' >"$RUN_DIR/warnings.json"
while IFS= read -r name; do
  jq -s '.[0] + .[1].warnings' "$RUN_DIR/warnings.json" "$RUN_DIR/reviews/$name/result.json" >"$RUN_DIR/next.json"
  mv "$RUN_DIR/next.json" "$RUN_DIR/warnings.json"
  if [ -f "$RUN_DIR/verifications/$name/result.json" ]; then
    jq -s '.[0] + .[1].verdicts' "$RUN_DIR/verdicts.json" "$RUN_DIR/verifications/$name/result.json" >"$RUN_DIR/next.json"
    mv "$RUN_DIR/next.json" "$RUN_DIR/verdicts.json"
    jq -s '.[0] + .[1].warnings' "$RUN_DIR/warnings.json" "$RUN_DIR/verifications/$name/result.json" >"$RUN_DIR/next.json"
    mv "$RUN_DIR/next.json" "$RUN_DIR/warnings.json"
  fi
done < <(jq -r '.[].name' <<<"$SELECTED")
jq -n --arg provider "$PROVIDER" --arg model "$MODEL" --slurpfile scope "$RUN_DIR/scope.json" \
  --slurpfile markdown_reports "$RUN_DIR/markdown-reports.jsonl" \
  --slurpfile candidates "$RUN_DIR/candidates.json" --slurpfile verdicts "$RUN_DIR/verdicts.json" --slurpfile warnings "$RUN_DIR/warnings.json" \
  '{complete:true,provider:$provider,model:$model,scope:$scope[0],warnings:$warnings[0],markdown_reports:$markdown_reports,
    findings:[$candidates[0][] as $c | $verdicts[0][] | select(.id == $c.id) | $c + {verification:.,reported_severity:$c.severity,severity:.severity}]}' >"$RUN_DIR/report.json"
printf 'Report: %s/report.json\n' "$RUN_DIR"
if jq -e 'any(.findings[]; .verification.status == "confirmed" and .severity == "high")' "$RUN_DIR/report.json" >/dev/null; then
  fail "Verified high-severity findings"
fi
printf '\033[32mAI review passed: no verified high-severity findings\033[0m\n'
