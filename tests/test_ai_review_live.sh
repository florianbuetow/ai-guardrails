#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -ne 2 ]; then
	printf 'Usage: %s PROVIDER MODEL\n' "$(basename "$0")" >&2
	exit 1
fi

PROVIDER=$1
MODEL=$2
case "$PROVIDER" in
codex | claude | grok) ;;
*)
	printf 'Unsupported provider: %s\n' "$PROVIDER" >&2
	exit 1
	;;
esac
[ -n "$MODEL" ] || {
	printf 'MODEL must be explicit and nonempty\n' >&2
	exit 1
}
[ -n "${HOME-}" ] || {
	printf 'HOME is required to preserve the provider login and write agent reports\n' >&2
	exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALLER="$REPO_ROOT/project-setup/setup-project-ai-review-claude.sh"
FIXTURE="$(mktemp -d "/tmp/ai-review-live.${PROVIDER}.XXXXXX")"
FIXTURE="$(cd "$FIXTURE" && pwd -P)"
PROJECT="$FIXTURE/project"
ARTIFACTS="$FIXTURE/artifacts"
RUN_LOG="$ARTIFACTS/live-review.log"

handoff() {
	local status=$?
	trap - EXIT
	printf 'FIXTURE=%s\n' "$FIXTURE"
	printf 'ARTIFACTS=%s\n' "$ARTIFACTS"
	if [ "$status" -ne 0 ]; then
		printf 'Live review fixture retained for failure analysis.\n' >&2
	fi
	exit "$status"
}
trap handoff EXIT

fail() {
	printf 'FAIL: %s\n' "$1" >&2
	exit 1
}

for command in git jq just shasum "$PROVIDER"; do
	command -v "$command" >/dev/null || fail "Required command is unavailable: $command"
done
[ -x "$INSTALLER" ] || fail "Installer is unavailable: $INSTALLER"

mkdir "$PROJECT" "$ARTIFACTS"
command -v "$PROVIDER" >"$ARTIFACTS/cli-path.txt"
"$PROVIDER" --version >"$ARTIFACTS/cli-version-before.txt" 2>&1
cat >"$PROJECT/README.md" <<'README'
# Calculator fixture

The goal is exact: `calculator.sh LEFT RIGHT` must print the mathematical product
of the two integer arguments. For example, `calculator.sh 6 7` must print `42`.
README
cat >"$PROJECT/calculator.sh" <<'CALCULATOR'
#!/usr/bin/env bash
set -euo pipefail

[ "$#" -eq 2 ] || {
	printf 'Usage: %s LEFT RIGHT\n' "$(basename "$0")" >&2
	exit 1
}
left=$1
right=$2
printf '%s\n' "$((left * right))"
CALCULATOR
chmod +x "$PROJECT/calculator.sh"

(cd "$PROJECT" && "$INSTALLER") >"$ARTIFACTS/install.log" 2>&1
next_config="$ARTIFACTS/config.json"
jq \
	--arg provider "$PROVIDER" \
	--arg model "$MODEL" \
	--arg reports "$ARTIFACTS" \
	'.providers[$provider].model = $model |
   .timeout_seconds = 300 |
   .report_directory = $reports' \
	"$PROJECT/config/ai-review/config.json" >"$next_config"
mv "$next_config" "$PROJECT/config/ai-review/config.json"

git -C "$PROJECT" init -q
git -C "$PROJECT" config user.email ai-review-live@example.invalid
git -C "$PROJECT" config user.name 'AI Review Live Test'
git -C "$PROJECT" ls-files --cached --others --exclude-standard -z | xargs -0 git -C "$PROJECT" add --
git -c core.hooksPath=/dev/null -c commit.gpgsign=false -C "$PROJECT" commit -q -m baseline

cat >"$PROJECT/calculator.sh" <<'BROKEN_CALCULATOR'
#!/usr/bin/env bash
set -euo pipefail

[ "$#" -eq 2 ] || {
	printf 'Usage: %s LEFT RIGHT\n' "$(basename "$0")" >&2
	exit 1
}
left=$1
right=$2
printf '%s\n' "$((left + right))"
BROKEN_CALCULATOR
chmod +x "$PROJECT/calculator.sh"

find "$PROJECT" -path "$PROJECT/.git" -prune -o -type f -print0 |
	LC_ALL=C sort -z |
	xargs -0 shasum >"$ARTIFACTS/project.before.sha"
touch "$ARTIFACTS/review-started.marker"

review_status=0
if env HOME="$HOME" just --justfile "$PROJECT/Justfile" --working-directory "$PROJECT" \
	"ci-ai-$PROVIDER" diff correctness >"$RUN_LOG" 2>&1; then
	review_status=0
else
	review_status=$?
fi

"$PROVIDER" --version >"$ARTIFACTS/cli-version-after.txt" 2>&1
cmp "$ARTIFACTS/cli-version-before.txt" "$ARTIFACTS/cli-version-after.txt" >/dev/null || fail 'CLI version changed during the test; rerun against a stable version'
find "$PROJECT" -path "$PROJECT/.git" -prune -o -type f -print0 |
	LC_ALL=C sort -z |
	xargs -0 shasum >"$ARTIFACTS/project.after.sha"
cmp "$ARTIFACTS/project.before.sha" "$ARTIFACTS/project.after.sha" >/dev/null ||
	fail 'AI review modified the disposable project'
[ "$review_status" -eq 1 ] || {
	cat "$RUN_LOG" >&2
	fail "expected verified high-severity exit 1, received $review_status"
}

report="$(sed -n 's/^Report: \(.*\/report\.json\)$/\1/p' "$RUN_LOG" | tail -n 1)"
if [ -z "$report" ]; then
	report="$(find "$ARTIFACTS" -mindepth 2 -maxdepth 2 -name report.json -type f -print | head -n 1)"
fi
[ -n "$report" ] && [ -f "$report" ] || {
	cat "$RUN_LOG" >&2
	fail 'consolidated report was not produced'
}

jq -e \
	--arg provider "$PROVIDER" \
	--arg model "$MODEL" \
	'(.complete == true) and
   (.provider == $provider) and
   (.model == $model) and
   (any(.findings[];
      .agent == "correctness" and
      .file == "calculator.sh" and
      .line >= 1 and
      .severity == "high" and
      .verification.status == "confirmed"))' \
	"$report" >/dev/null || {
	jq . "$report" >&2
	fail 'report lacks a confirmed high-severity correctness finding at calculator.sh'
}

markdown_count="$(jq -r '.markdown_reports[] | select(.agent == "correctness") | .path' "$report" |
	while IFS= read -r path; do
		case "$path" in
		"$HOME/reports/ai-review/"*.md) ;;
		*) fail "agent report is outside HOME/reports/ai-review: $path" ;;
		esac
		[ -s "$path" ] || fail "agent Markdown report is missing or empty: $path"
		[ "$path" -nt "$ARTIFACTS/review-started.marker" ] || fail "agent Markdown report predates this run: $path"
		printf '.\n'
	done | wc -l | tr -d ' ')"
[ "$markdown_count" -eq 2 ] || fail "expected reviewer and verifier Markdown reports, found $markdown_count"

cp "$report" "$ARTIFACTS/report.json"
printf 'PASS: %s/%s found and verified the calculator multiplication regression.\n' "$PROVIDER" "$MODEL"
