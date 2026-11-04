#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE="$REPO_ROOT/blueprints/ai-review/template"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ai-review-runner-tests.XXXXXX")"
TEST_ROOT="$(cd "$TEST_ROOT" && pwd -P)"
FAKE_BIN="$TEST_ROOT/fake-bin"
tests_run=0

cleanup() {
	local status=$?
	trap - EXIT INT TERM
	if [ "${KEEP_AI_REVIEW_TESTS:-0}" = 1 ]; then
		printf 'Preserved test directory: %s\n' "$TEST_ROOT" >&2
		exit "$status"
	fi
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

assert_contains() {
	local path="$1"
	local expected="$2"
	if ! grep -qF -- "$expected" "$path"; then
		printf '%s\n' "--- $path ---" >&2
		sed -n '1,240p' "$path" >&2
		fail "$path does not contain: $expected"
	fi
}

assert_not_contains() {
	local path="$1"
	local unexpected="$2"
	if grep -qF -- "$unexpected" "$path"; then
		fail "$path unexpectedly contains: $unexpected"
	fi
}

assert_jq() {
	local path="$1"
	local expression="$2"
	if ! jq -e "$expression" "$path" >/dev/null; then
		jq . "$path" >&2
		fail "$path does not satisfy jq expression: $expression"
	fi
}

run_expect() {
	local expected_status="$1"
	local output="$2"
	shift 2
	local actual_status
	if "$@" >"$output" 2>&1; then
		actual_status=0
	else
		actual_status=$?
	fi
	if [ "$actual_status" -ne "$expected_status" ]; then
		cat "$output" >&2
		fail "command returned $actual_status, expected $expected_status: $*"
	fi
}

write_config() {
	local project="$1"
	local report_directory="$2"
	jq -n \
		--arg reports "$report_directory" \
		'{
      providers: {
        codex: {model: "test-codex-model"},
        claude: {model: "test-claude-model"},
        grok: {model: "test-grok-model"}
      },
      agents: [
        {name: "security", prompt: "security.md", description: "security specialist", enabled: true},
        {name: "performance", prompt: "performance.md", description: "performance specialist", enabled: true},
        {name: "disabled", prompt: "disabled.md", description: "disabled specialist", enabled: false}
      ],
      verifier: {prompt: "finding-verifier.md"},
      timeout_seconds: 5,
      report_directory: $reports
    }' >"$project/config/ai-review/config.json"
}

write_prompts() {
	local project="$1"
	local prompts="$project/config/ai-review/prompts"
	local fragments="$project/config/ai-review/fragments"
	mkdir -p "$prompts" "$fragments"
	printf 'SECURITY REVIEW\n{{shared}}\n' >"$prompts/security.md"
	printf 'PERFORMANCE REVIEW\n{{shared}}\n' >"$prompts/performance.md"
	printf 'DISABLED REVIEW\n' >"$prompts/disabled.md"
	printf 'VERIFY FINDINGS\n{{shared}}\n' >"$prompts/finding-verifier.md"
	printf 'SHARED START {{nested}} SHARED END\n' >"$fragments/shared.md"
	printf 'NESTED CONTENT\n' >"$prompts/nested.md"
}

home_for_project() {
	printf '%s.home\n' "$1"
}

new_project() {
	local name="$1"
	local project="$TEST_ROOT/$name"
	mkdir -p "$project/scripts/ai-review" "$project/config/ai-review/schemas" "$project/just" "$project/reports"
	mkdir "$(home_for_project "$project")"
	cp "$TEMPLATE/scripts/ai-review/review.sh" "$project/scripts/ai-review/review.sh"
	cp "$TEMPLATE/scripts/ai-review/providers.sh" "$project/scripts/ai-review/providers.sh"
	cp "$TEMPLATE/scripts/ai-review/read-tools.sh" "$project/scripts/ai-review/read-tools.sh"
	cp "$TEMPLATE/just/ai-review.just" "$project/just/ai-review.just"
	printf "import 'just/ai-review.just'\n" >"$project/Justfile"
	write_config "$project" "$project/reports"
	write_prompts "$project"
	printf '{}\n' >"$project/config/ai-review/schemas/findings.json"
	printf '{}\n' >"$project/config/ai-review/schemas/verification.json"
	printf 'tracked before\n' >"$project/reviewed.txt"
	printf '%s\n' "$project"
}

new_production_prompt_project() {
	local name="$1"
	local project
	project="$(new_project "$name")"
	rm -rf -- "$project/config/ai-review"
	cp -R "$TEMPLATE/config/ai-review" "$project/config/ai-review"
	jq \
		--arg reports "$project/reports" \
		'.providers.codex.model = "test-codex-model" |
     .timeout_seconds = 20 |
     .report_directory = $reports' \
		"$project/config/ai-review/config.json" >"$project/config/ai-review/config.next.json"
	mv "$project/config/ai-review/config.next.json" "$project/config/ai-review/config.json"
	printf '%s\n' "$project"
}

initialize_git() {
	local project="$1"
	git -C "$project" init -q
	git -C "$project" config user.email ai-review-tests@example.invalid
	git -C "$project" config user.name 'AI Review Tests'
	git -C "$project" ls-files --cached --others --exclude-standard -z | xargs -0 git -C "$project" add --
	git -C "$project" commit -q -m base
}

commit_paths() {
	local project="$1"
	local message="$2"
	shift 2
	git -C "$project" add -- "$@"
	git -C "$project" commit -q -m "$message"
}

run_review() {
	local project="$1"
	local expected_status="$2"
	local output="$3"
	shift 3
	run_expect "$expected_status" "$output" env \
		PATH="$FAKE_BIN:$PATH" \
		HOME="$(home_for_project "$project")" \
		FAKE_REVIEW_LOG_DIR="$project/fake-log" \
		bash "$project/scripts/ai-review/review.sh" "$@"
}

latest_report() {
	local project="$1"
	find "$project/reports" -mindepth 2 -maxdepth 2 -name report.json -type f -print | sort | tail -n 1
}

report_from_output() {
	local output="$1"
	sed -n 's/^Report: \(.*\/report\.json\)$/\1/p' "$output" | tail -n 1
}

latest_prompt_for_phase() {
	local project="$1"
	local phase="$2"
	local call
	for call in "$project"/fake-log/call.*; do
		if [ -f "$call/phase" ] && [ "$(cat "$call/phase")" = "$phase" ]; then
			printf '%s\n' "$call/prompt"
		fi
	done | sort | tail -n 1
}

review_input_from_prompt() {
	local prompt="$1"
	awk 'found {print} /^REVIEW_INPUT_JSON$/ {found=1}' "$prompt"
}

write_fake_cli() {
	local provider="$1"
	local destination="$FAKE_BIN/$provider"
	cp "$TEST_ROOT/fake-provider" "$destination"
	chmod +x "$destination"
}

mkdir "$FAKE_BIN"
cat >"$TEST_ROOT/fake-provider" <<'FAKE_PROVIDER'
#!/usr/bin/env bash
set -euo pipefail

provider="$(basename "$0")"
stdin_file="$(mktemp "${TMPDIR:-/tmp}/ai-review-fake-stdin.XXXXXX")"
trap 'rm -f -- "$stdin_file"' EXIT INT TERM
cat >"$stdin_file"
prompt=''
if [ -s "$stdin_file" ]; then
  prompt="$(cat "$stdin_file")"
fi
previous=''
for argument in "$@"; do
  if [ "$previous" = '--prompt-file' ] && [ -f "$argument" ]; then
    prompt="$(cat "$argument")"
  elif { [ "$previous" = '-p' ] || [ "$previous" = '--prompt' ]; } && [[ "$argument" != -* ]]; then
    prompt="$argument"
  fi
  previous="$argument"
done
if [ -z "$prompt" ]; then
  printf 'fake %s received no prompt\n' "$provider" >&2
  exit 91
fi

input_json="$(printf '%s\n' "$prompt" | awk 'found {print} /^REVIEW_INPUT_JSON$/ {found=1}')"
if ! printf '%s\n' "$input_json" | jq -e . >/dev/null; then
  printf 'fake %s received invalid REVIEW_INPUT_JSON\n' "$provider" >&2
  exit 92
fi
call="$(mktemp -d "$FAKE_REVIEW_LOG_DIR/call.XXXXXX")"
printf '%s\n' "$provider" >"$call/provider"
printf '%s\n' "$$" >"$call/pid"
printf '%s\n' "$*" >"$call/arguments"
printf '%s\n' "$prompt" >"$call/prompt"

if printf '%s\n' "$input_json" | jq -e 'has("candidates")' >/dev/null; then
  phase=verify
else
  phase=review
fi
printf '%s\n' "$phase" >"$call/phase"
agent="$(printf '%s\n' "$input_json" | jq -r '.agent')"
diff_path="$(printf '%s\n' "$input_json" | jq -r '.diff_path // empty')"
if [ -n "$diff_path" ] && [ -f "$diff_path" ]; then
  cp "$diff_path" "$call/diff"
fi
report_path="$(printf '%s\n' "$input_json" | jq -r '.report_path // empty')"
if [ -n "$report_path" ] && [ "${FAKE_REPORT_MODE:-write}" != missing ]; then
  case "$report_path" in
    "$HOME/reports/ai-review/"*.md) ;;
    *) printf 'invalid assigned Markdown report path: %s\n' "$report_path" >&2; exit 97 ;;
  esac
  mkdir -p "$(dirname "$report_path")"
  printf '# Fake %s report\n\nProvider: %s\n' "$phase" "$provider" >"$report_path"
fi

if [ "$phase" = review ] && [ "$agent" = "${FAKE_FAIL_AGENT:-}" ]; then
  printf 'injected agent failure: %s\n' "$agent" >&2
  exit 98
fi
if [ "$phase" = review ] && [ "$agent" = "${FAKE_SLEEP_AGENT:-}" ]; then
  sleep "${FAKE_SLEEP_SECONDS:-5}"
fi

if [ "$phase" = review ]; then
  if [ "${FAKE_REVIEW_MODE:-success}" = error ]; then
    printf 'injected reviewer failure\n' >&2
    exit 93
  fi
  if [ "${FAKE_REVIEW_MODE:-success}" = incomplete ]; then
    result='{"complete":false,"findings":[],"warnings":[]}'
  else
    severity="${FAKE_REVIEW_SEVERITY:-low}"
		finding_file=reviewed.txt
		finding_line=1
		if [ "${FAKE_FINDING_LOCATION:-valid}" = missing ]; then
			finding_file=missing.txt
		elif [ "${FAKE_FINDING_LOCATION:-valid}" = out-of-bounds ]; then
			finding_line=2
		fi
		result="$(jq -n --arg severity "$severity" --arg file "$finding_file" --argjson line "$finding_line" '{
      complete: true,
      findings: [{
        severity: $severity,
        file: $file,
        line: $line,
        title: "Fake actionable finding",
        description: "A concrete fake defect description.",
        evidence: "The first line supports this finding.",
        basis: "workspace"
      }],
      warnings: []
    }')"
  fi
else
  if [ "${FAKE_VERIFIER_MODE:-success}" = error ]; then
    printf 'injected verifier failure\n' >&2
    exit 94
  fi
  if [ "${FAKE_VERIFIER_MODE:-success}" = incomplete ]; then
    result='{"complete":false,"verdicts":[],"warnings":[]}'
  else
    status="${FAKE_VERIFIER_STATUS:-confirmed}"
    result="$(printf '%s\n' "$input_json" | jq --arg status "$status" '{
      complete: true,
      verdicts: [.candidates[] | {
        id: .id,
        status: $status,
        severity: .severity,
        reason: "The fake verifier reached a deterministic verdict.",
        basis: "workspace"
      }],
      warnings: []
    }')"
  fi
fi

if [ "${FAKE_OUTPUT_MODE:-valid}" = invalid ]; then
  result='{invalid json'
fi
if [ "${FAKE_REVIEW_MODE:-success}" = ignore-term ]; then
	trap '' TERM
	while :; do sleep 1; done
fi
case "$provider" in
  codex)
    output_file=''
    previous=''
    for argument in "$@"; do
      if [ "$previous" = '-o' ] || [ "$previous" = '--output-last-message' ]; then
        output_file="$argument"
      fi
      previous="$argument"
    done
    if [ -z "$output_file" ]; then
      printf 'fake codex received no result-file argument\n' >&2
      exit 95
    fi
    printf '%s\n' "$result" >"$output_file"
    ;;
  claude)
    jq -n --argjson structured "$result" '{is_error: false, structured_output: $structured}'
    ;;
  grok)
    jq -cn '{type:"assistant",message:{stop_reason:"tool_use",content:[{type:"text",text:"progress"}]}}'
    split_at=$((${#result} / 2))
    first_text=${result:0:split_at}
    second_text=${result:split_at}
    jq -cn --arg first "$first_text" --arg second "$second_text" \
      '{type:"assistant",message:{stop_reason:"end_turn",content:[{type:"text",text:$first},{type:"tool_use",name:"ignored"},{type:"text",text:$second}]}}'
    if [ "${FAKE_OUTPUT_MODE:-valid}" = multiple ]; then
      jq -cn --arg text "$result" '{type:"assistant",message:{stop_reason:"end_turn",content:[{type:"text",text:$text}]}}'
    fi
    ;;
  *)
    printf 'unexpected fake provider: %s\n' "$provider" >&2
    exit 96
    ;;
esac
FAKE_PROVIDER
chmod +x "$TEST_ROOT/fake-provider"
for provider in codex claude grok; do
	write_fake_cli "$provider"
done

test_shell_only_and_help_needs_no_provider_auth() {
	if [ -e "$TEMPLATE/scripts/ai-review/review.py" ]; then
		fail 'obsolete Python runner still exists'
	fi
	if grep -RqiF python "$TEMPLATE/scripts/ai-review" "$TEMPLATE/just/ai-review.just"; then
		fail 'AI review runner or Just recipes still invoke Python'
	fi
	local project
	project="$(new_project help)"
	mkdir "$project/fake-log"
	local output="$project/help.txt"
	run_expect 0 "$output" env PATH="$FAKE_BIN:$PATH" HOME="$(home_for_project "$project")" FAKE_REVIEW_LOG_DIR="$project/fake-log" \
		bash "$project/scripts/ai-review/review.sh" help
	for expected in codex claude grok security performance 'security specialist'; do
		assert_contains "$output" "$expected"
	done
	assert_contains "$output" 'disabled specialist (disabled)'
	if find "$project/fake-log" -mindepth 1 -print -quit | grep -q .; then
		fail 'help invoked a provider CLI'
	fi
}

test_registry_rejects_unknown_provider_and_agent() {
	local project
	project="$(new_project registry)"
	initialize_git "$project"
	mkdir "$project/fake-log"
	run_review "$project" 1 "$project/provider.txt" run unknown global security
	assert_contains "$project/provider.txt" 'unknown'
	run_review "$project" 1 "$project/agent.txt" run codex global unknown
	assert_contains "$project/agent.txt" 'unknown'
	if find "$project/fake-log" -mindepth 1 -print -quit | grep -q .; then
		fail 'invalid registry selection invoked a provider CLI'
	fi
}

test_recursive_prompt_expansion_and_template_failures() {
	local project
	project="$(new_project templates)"
	initialize_git "$project"
	mkdir "$project/fake-log"
	run_review "$project" 0 "$project/valid.txt" run codex global security
	local review_prompt
	review_prompt="$(latest_prompt_for_phase "$project" review)"
	assert_contains "$review_prompt" 'SECURITY REVIEW'
	assert_contains "$review_prompt" 'SHARED START NESTED CONTENT'
	assert_not_contains "$review_prompt" '{{'

	rm -rf -- "$project/fake-log"
	mkdir "$project/fake-log"
	printf 'BROKEN {{missing}}\n' >"$project/config/ai-review/prompts/security.md"
	run_review "$project" 1 "$project/missing.txt" run codex global security
	assert_contains "$project/missing.txt" missing
	if find "$project/fake-log" -mindepth 1 -print -quit | grep -q .; then
		fail 'missing prompt fragment invoked a provider CLI'
	fi

	printf '{{cycle-b}}\n' >"$project/config/ai-review/prompts/security.md"
	printf '{{security}}\n' >"$project/config/ai-review/fragments/cycle-b.md"
	run_review "$project" 1 "$project/cycle.txt" run codex global security
	assert_contains "$project/cycle.txt" 'Circular prompt include'

	printf '{{../outside}}\n' >"$project/config/ai-review/prompts/security.md"
	run_review "$project" 1 "$project/token.txt" run codex global security
	assert_contains "$project/token.txt" 'Invalid template reference'
}

test_production_prompt_graph_expands_all_enabled_agents() {
	local project report call prompt input phase agent review_count verification_count
	project="$(new_production_prompt_project production-prompts)"
	initialize_git "$project"
	mkdir "$project/fake-log"
	run_review "$project" 0 "$project/output.txt" run codex global
	report="$(latest_report "$project")"
	assert_jq "$report" ' .complete == true'
	if ! jq -e --slurpfile config "$project/config/ai-review/config.json" '
    ([.findings[].agent] | unique | sort) ==
    ([$config[0].agents[] | select(.enabled) | .name] | sort)
  ' "$report" >/dev/null; then
		jq . "$report" >&2
		fail 'production prompt run did not cover every enabled agent'
	fi
	review_count=0
	verification_count=0
	for call in "$project"/fake-log/call.*; do
		prompt="$call/prompt"
		input="$(review_input_from_prompt "$prompt")"
		phase="$(cat "$call/phase")"
		agent="$(printf '%s\n' "$input" | jq -r .agent)"
		[ -n "$agent" ] || fail 'production prompt omitted its agent identity'
		assert_not_contains "$prompt" '{{'
		assert_contains "$prompt" '## Severity levels'
		assert_contains "$prompt" '## Required Markdown report file'
		assert_contains "$prompt" '## Read-only investigation'
		if [ "$phase" = review ]; then
			review_count=$((review_count + 1))
			assert_contains "$prompt" '## Report format'
		else
			verification_count=$((verification_count + 1))
			assert_contains "$prompt" '## Verification report'
		fi
	done
	[ "$review_count" -eq 8 ] || fail "production prompt graph launched $review_count reviewers, expected eight"
	[ "$verification_count" -eq 8 ] || fail "production prompt graph launched $verification_count verifiers, expected eight"
}

test_all_provider_envelopes_and_models() {
	local provider project report calls markdown_root markdown_count call input assigned
	for provider in codex claude grok; do
		project="$(new_project "provider-$provider")"
		initialize_git "$project"
		mkdir "$project/fake-log"
		run_review "$project" 0 "$project/output.txt" run "$provider" global security
		report="$(latest_report "$project")"
		[ -n "$report" ] || fail "$provider did not produce a report"
		assert_jq "$report" '.complete == true'
		assert_jq "$report" '.findings | length == 1'
		calls="$(find "$project/fake-log" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
		[ "$calls" -eq 2 ] || fail "$provider made $calls calls, expected review plus verification"
		if ! grep -RqsF "test-$provider-model" "$project/fake-log"/call.*/arguments; then
			fail "$provider did not receive its configured model"
		fi
		markdown_root="$(home_for_project "$project")/reports/ai-review"
		markdown_count="$(find "$markdown_root" -maxdepth 1 -name '*.md' -type f | wc -l | tr -d ' ')"
		[ "$markdown_count" -eq 2 ] || fail "$provider wrote $markdown_count Markdown reports, expected two"
		for call in "$project"/fake-log/call.*; do
			input="$(review_input_from_prompt "$call/prompt")"
			assigned="$(printf '%s\n' "$input" | jq -r .report_path)"
			[ -s "$assigned" ] || fail "$provider did not write assigned Markdown report: $assigned"
			if ! basename "$assigned" | grep -Eq "^[0-9]{14}_${provider}_(reviews|verifications)_security_ai-review\.[A-Za-z0-9]{6}\.md$"; then
				fail "$provider received a noncanonical Markdown report path: $assigned"
			fi
			case "$provider" in
			# Claude's permission grammar prefixes filesystem-absolute paths with an extra slash.
			claude) assert_contains "$call/arguments" "Edit(/$assigned)" ;;
			codex)
				assert_contains "$call/arguments" '--disable shell_tool'
				assert_contains "$call/arguments" '--disable unified_exec'
				assert_contains "$call/arguments" '--disable hooks'
				assert_not_contains "$call/arguments" '--disable code_mode_host'
				assert_contains "$call/arguments" 'mcp_servers.ai_review_files.enabled_tools=["read_file","list_files","search","write_report"]'
				for tool in read_file list_files search write_report; do
					assert_contains "$call/arguments" "mcp_servers.ai_review_files.tools.$tool.approval_mode=\"approve\""
				done
				assert_contains "$call/arguments" "$assigned"
				;;
			grok)
				assert_contains "$call/arguments" '--output-format streaming-messages-json'
				assert_contains "$call/arguments" 'search_tool,use_tool'
				assert_contains "$call/arguments" 'MCPTool(*)'
				assert_contains "$call/arguments" "Write($assigned)"
				assert_not_contains "$call/arguments" '--add-dir'
				;;
			esac
		done
		if ! git -C "$project" diff --quiet --; then
			git -C "$project" diff -- >&2
			fail "$provider modified tracked project content"
		fi
	done
}

test_later_failure_cancels_slow_sibling() {
	local project started elapsed call pid
	project="$(new_project failfast)"
	initialize_git "$project"
	mkdir "$project/fake-log"
	started=$SECONDS
	FAKE_SLEEP_AGENT=security FAKE_SLEEP_SECONDS=8 FAKE_FAIL_AGENT=performance run_review "$project" 1 "$project/output.txt" run codex global
	assert_contains "$project/output.txt" 'Session reviews/performance failed'
	elapsed=$((SECONDS - started))
	[ "$elapsed" -lt 8 ] || fail "Later failure waited for slow sibling: ${elapsed}s"
	for call in "$project"/fake-log/call.*; do
		pid=$(cat "$call/pid")
		if kill -0 "$pid" 2>/dev/null; then fail "Sibling CLI survived failure: $pid"; fi
	done
}

test_all_enabled_agents_have_distinct_ids() {
	local project report
	project="$(new_project all-agents)"
	initialize_git "$project"
	mkdir "$project/fake-log"
	run_review "$project" 0 "$project/output.txt" run codex global
	report="$(latest_report "$project")"
	assert_jq "$report" '([.findings[].id] | length) == 2'
	assert_jq "$report" '[.findings[].id | test("^(performance|security)-[0-9]+$")] | all'
	assert_jq "$report" '[.findings[].id] | length == (unique | length)'
	assert_jq "$report" '[.findings[].verification.status] | unique == ["confirmed"]'
	local calls
	calls="$(find "$project/fake-log" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
	[ "$calls" -eq 4 ] || fail "all-agent run made $calls calls, expected four"
}

test_confirmed_severity_and_rejection_control_exit_status() {
	local severity expected project report
	for severity in low medium high; do
		expected=0
		if [ "$severity" = high ]; then
			expected=1
		fi
		project="$(new_project "severity-$severity")"
		initialize_git "$project"
		mkdir "$project/fake-log"
		run_expect "$expected" "$project/output.txt" env \
			PATH="$FAKE_BIN:$PATH" HOME="$(home_for_project "$project")" FAKE_REVIEW_LOG_DIR="$project/fake-log" FAKE_REVIEW_SEVERITY="$severity" \
			bash "$project/scripts/ai-review/review.sh" run codex global security
		report="$(latest_report "$project")"
		assert_jq "$report" ".findings[0].severity == \"$severity\""
		assert_jq "$report" '.findings[0].verification.status == "confirmed"'
	done

	project="$(new_project rejected-high)"
	initialize_git "$project"
	mkdir "$project/fake-log"
	run_expect 0 "$project/output.txt" env \
		PATH="$FAKE_BIN:$PATH" HOME="$(home_for_project "$project")" FAKE_REVIEW_LOG_DIR="$project/fake-log" \
		FAKE_REVIEW_SEVERITY=high FAKE_VERIFIER_STATUS=rejected \
		bash "$project/scripts/ai-review/review.sh" run codex global security
	report="$(latest_report "$project")"
	assert_jq "$report" '.findings[0].severity == "high"'
	assert_jq "$report" '.findings[0].verification.status == "rejected"'
}

test_provider_and_verifier_errors_fail_closed() {
	local mode variable project report
	for mode in review-error review-incomplete verify-error verify-incomplete invalid-json multiple-json missing-location out-of-bounds missing-report; do
		project="$(new_project "$mode")"
		initialize_git "$project"
		mkdir "$project/fake-log"
		variable=()
		case "$mode" in
		review-error) variable=(FAKE_REVIEW_MODE=error) ;;
		review-incomplete) variable=(FAKE_REVIEW_MODE=incomplete) ;;
		verify-error) variable=(FAKE_VERIFIER_MODE=error) ;;
		verify-incomplete) variable=(FAKE_VERIFIER_MODE=incomplete) ;;
		invalid-json) variable=(FAKE_OUTPUT_MODE=invalid) ;;
		multiple-json) variable=(FAKE_OUTPUT_MODE=multiple) ;;
		missing-location) variable=(FAKE_FINDING_LOCATION=missing) ;;
		out-of-bounds) variable=(FAKE_FINDING_LOCATION=out-of-bounds) ;;
		missing-report) variable=(FAKE_REPORT_MODE=missing) ;;
		esac
		run_expect 1 "$project/output.txt" env \
			PATH="$FAKE_BIN:$PATH" HOME="$(home_for_project "$project")" FAKE_REVIEW_LOG_DIR="$project/fake-log" "${variable[@]}" \
			bash "$project/scripts/ai-review/review.sh" run grok global security
		report="$(latest_report "$project")"
		if [ -n "$report" ] && jq -e '.complete == true' "$report" >/dev/null; then
			fail "$mode produced a complete successful report"
		fi
	done
}

test_hard_timeout_kills_term_resistant_cli() {
	local project next_config started elapsed timeout_file pid
	project="$(new_project hard-timeout)"
	initialize_git "$project"
	mkdir "$project/fake-log"
	next_config="$project/config/ai-review/config.next.json"
	jq '.timeout_seconds = 1' "$project/config/ai-review/config.json" >"$next_config"
	mv "$next_config" "$project/config/ai-review/config.json"
	started=$SECONDS
	run_expect 1 "$project/output.txt" env \
		PATH="$FAKE_BIN:$PATH" HOME="$(home_for_project "$project")" \
		FAKE_REVIEW_LOG_DIR="$project/fake-log" FAKE_REVIEW_MODE=ignore-term \
		bash "$project/scripts/ai-review/review.sh" run grok global security
	elapsed=$((SECONDS - started))
	[ "$elapsed" -le 10 ] || fail "TERM-resistant CLI exceeded bounded timeout: ${elapsed}s"
	timeout_file="$(find "$project/reports" -name '*.timeout' -type f -print -quit)"
	[ -n "$timeout_file" ] || fail 'timeout did not leave explicit timeout evidence'
	pid="$(cat "$project"/fake-log/call.*/pid)"
	if kill -0 "$pid" 2>/dev/null; then
		fail "TERM-resistant fake CLI is still running: $pid"
	fi
}

test_read_helper_limits_writes_to_assigned_report() {
	local project helper_root diff schema assigned responses before after
	project="$(new_project read-helper)"
	helper_root="$project/helper-workspace"
	mkdir "$helper_root"
	printf 'immutable project content\n' >"$helper_root/source.txt"
	diff="$TEST_ROOT/read-helper.diff"
	schema="$TEST_ROOT/read-helper.schema.json"
	assigned="$(home_for_project "$project")/reports/ai-review/assigned.md"
	mkdir -p "$(dirname "$assigned")"
	printf 'diff content\n' >"$diff"
	printf '{}\n' >"$schema"
	before="$(shasum "$helper_root/source.txt")"
	responses="$project/read-helper-responses.jsonl"
	{
		jq -cn '{jsonrpc:"2.0",id:1,method:"initialize",params:{}}'
		jq -cn --arg path "$helper_root/source.txt" '{jsonrpc:"2.0",id:2,method:"tools/call",params:{name:"read_file",arguments:{path:$path}}}'
		jq -cn '{jsonrpc:"2.0",id:3,method:"tools/call",params:{name:"search",arguments:{text:"immutable"}}}'
		jq -cn '{jsonrpc:"2.0",id:4,method:"tools/call",params:{name:"read_file",arguments:{path:"../outside"}}}'
		jq -cn '{jsonrpc:"2.0",id:5,method:"tools/call",params:{name:"write_report",arguments:{markdown:"# Assigned report"}}}'
	} | bash "$project/scripts/ai-review/read-tools.sh" "$helper_root" "$diff" "$assigned" "$schema" >"$responses"
	after="$(shasum "$helper_root/source.txt")"
	[ "$before" = "$after" ] || fail 'read helper modified a project file'
	[ "$(cat "$assigned")" = '# Assigned report' ] || fail 'read helper did not write the exact assigned report'
	jq -s -e 'any(.[]; .id == 2 and (.result.content[0].text | contains("immutable project content")))' "$responses" >/dev/null ||
		fail 'read helper could not read an allowed project file'
	jq -s -e 'any(.[]; .id == 3 and (.result.content[0].text | contains("source.txt")))' "$responses" >/dev/null ||
		fail 'read helper search did not return the project match'
	jq -s -e 'any(.[]; .id == 4 and .result.isError == true)' "$responses" >/dev/null ||
		fail 'read helper accepted parent traversal'
	[ "$(find "$helper_root" -maxdepth 1 -type f | wc -l | tr -d ' ')" -eq 1 ] || fail 'read helper wrote inside the project'
}

test_commit_scope_defaults_to_head_and_accepts_root_hash() {
	local project root_commit head_commit prompt input workspace
	project="$(new_project commit-scope)"
	initialize_git "$project"
	root_commit="$(git -C "$project" rev-parse HEAD)"
	printf 'tracked after\n' >"$project/reviewed.txt"
	commit_paths "$project" head reviewed.txt
	head_commit="$(git -C "$project" rev-parse HEAD)"
	mkdir "$project/fake-log"

	(cd "$project/config" && env PATH="$FAKE_BIN:$PATH" HOME="$(home_for_project "$project")" FAKE_REVIEW_LOG_DIR="$project/fake-log" \
		bash "$project/scripts/ai-review/review.sh" run codex commit security) >"$project/head.txt" 2>&1
	prompt="$(latest_prompt_for_phase "$project" review)"
	input="$(review_input_from_prompt "$prompt")"
	[ "$(printf '%s\n' "$input" | jq -r .commit)" = "$head_commit" ] || fail 'commit scope did not default to HEAD'
	workspace="$(printf '%s\n' "$input" | jq -r .workspace)"
	[ "$(cat "$workspace/reviewed.txt")" = 'tracked after' ] || fail 'default commit workspace does not contain HEAD'

	rm -rf -- "$project/fake-log"
	mkdir "$project/fake-log"
	run_review "$project" 0 "$project/root.txt" run codex commit security "$root_commit"
	prompt="$(latest_prompt_for_phase "$project" review)"
	input="$(review_input_from_prompt "$prompt")"
	[ "$(printf '%s\n' "$input" | jq -r .commit)" = "$root_commit" ] || fail 'specified root commit was not reviewed'
	workspace="$(printf '%s\n' "$input" | jq -r .workspace)"
	[ "$(cat "$workspace/reviewed.txt")" = 'tracked before' ] || fail 'root commit workspace contains the wrong revision'
}

test_commit_scope_preserves_exact_tree_despite_archive_attributes() {
	local project commit prompt input workspace
	project="$(new_project commit-attributes)"
	printf 'export-ignored.txt export-ignore\nsubstituted.txt export-subst\n' >"$project/.gitattributes"
	printf 'must remain in exact commit tree\n' >"$project/export-ignored.txt"
	printf '%s\n' "literal \$Format:%H\$ marker" >"$project/substituted.txt"
	initialize_git "$project"
	commit="$(git -C "$project" rev-parse HEAD)"
	mkdir "$project/fake-log"
	run_review "$project" 0 "$project/output.txt" run codex commit security "$commit"
	prompt="$(latest_prompt_for_phase "$project" review)"
	input="$(review_input_from_prompt "$prompt")"
	workspace="$(printf '%s\n' "$input" | jq -r .workspace)"
	[ "$(cat "$workspace/export-ignored.txt")" = 'must remain in exact commit tree' ] ||
		fail 'commit extraction honored export-ignore and omitted tracked content'
	[ "$(cat "$workspace/substituted.txt")" = "literal \$Format:%H\$ marker" ] ||
		fail 'commit extraction altered export-subst content'
}

test_diff_scope_includes_untracked_and_excludes_ignored_files() {
	local project prompt input diff_copy
	project="$(new_project diff-scope)"
	printf 'ignored.txt\n' >"$project/.gitignore"
	initialize_git "$project"
	printf 'tracked changed\n' >"$project/reviewed.txt"
	printf 'untracked review content\n' >"$project/untracked.txt"
	printf 'ignored secret\n' >"$project/ignored.txt"
	mkdir "$project/fake-log"
	run_review "$project" 0 "$project/output.txt" run codex diff security
	prompt="$(latest_prompt_for_phase "$project" review)"
	input="$(review_input_from_prompt "$prompt")"
	printf '%s\n' "$input" | jq -e '.scope == "diff"' >/dev/null || fail 'diff scope metadata is wrong'
	printf '%s\n' "$input" | jq -e '.files | index("reviewed.txt") != null' >/dev/null || fail 'tracked change missing'
	printf '%s\n' "$input" | jq -e '.files | index("untracked.txt") != null' >/dev/null || fail 'untracked file missing'
	printf '%s\n' "$input" | jq -e '.files | index("ignored.txt") == null' >/dev/null || fail 'ignored file included'
	diff_copy="$(find "$project/fake-log" -name diff -type f -print | head -n 1)"
	[ -n "$diff_copy" ] || fail 'fake reviewer could not inspect diff_path'
	assert_contains "$diff_copy" 'tracked changed'
	assert_not_contains "$diff_copy" 'ignored secret'
}

test_global_scope_and_unique_reports_via_just_in_path_with_spaces() {
	local project first_report second_report prompt input
	project="$(new_project 'just project with spaces')"
	initialize_git "$project"
	mkdir "$project/fake-log"
	run_expect 0 "$project/first.txt" env PATH="$FAKE_BIN:$PATH" HOME="$(home_for_project "$project")" FAKE_REVIEW_LOG_DIR="$project/fake-log" \
		just --justfile "$project/Justfile" --working-directory "$project" ci-ai-codex global security
	first_report="$(report_from_output "$project/first.txt")"
	[ -n "$first_report" ] || fail 'Just recipe did not produce a report'
	prompt="$(latest_prompt_for_phase "$project" review)"
	input="$(review_input_from_prompt "$prompt")"
	printf '%s\n' "$input" | jq -e '.scope == "global" and .commit == "" and .base == ""' >/dev/null ||
		fail 'global scope metadata is wrong'

	rm -rf -- "$project/fake-log"
	mkdir "$project/fake-log"
	run_review "$project" 0 "$project/second.txt" run codex global security
	second_report="$(report_from_output "$project/second.txt")"
	[ "$first_report" != "$second_report" ] || fail 'two reviews reused the same report path'
	[ -f "$first_report" ] && [ -f "$second_report" ] || fail 'a unique report was overwritten'
}

for test_function in \
	test_shell_only_and_help_needs_no_provider_auth \
	test_registry_rejects_unknown_provider_and_agent \
	test_recursive_prompt_expansion_and_template_failures \
	test_all_provider_envelopes_and_models \
	test_production_prompt_graph_expands_all_enabled_agents \
	test_later_failure_cancels_slow_sibling \
	test_all_enabled_agents_have_distinct_ids \
	test_confirmed_severity_and_rejection_control_exit_status \
	test_provider_and_verifier_errors_fail_closed \
	test_hard_timeout_kills_term_resistant_cli \
	test_read_helper_limits_writes_to_assigned_report \
	test_commit_scope_defaults_to_head_and_accepts_root_hash \
	test_commit_scope_preserves_exact_tree_despite_archive_attributes \
	test_diff_scope_includes_untracked_and_excludes_ignored_files \
	test_global_scope_and_unique_reports_via_just_in_path_with_spaces; do
	"$test_function"
	tests_run=$((tests_run + 1))
	printf 'PASS: %s\n' "$test_function"
done

printf 'AI review runner tests passed: %d\n' "$tests_run"
