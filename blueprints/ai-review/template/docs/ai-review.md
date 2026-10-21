# AI review

Run five independent specialist sessions against the same pair of Git commits:
correctness, security, performance, architecture, and tests/guardrails. Each session
uses a fresh temporary working directory and a domain-specific prompt. The selected
provider runs all five domains sequentially; the report preserves each verdict.
This costs five model calls (potentially more internal turns) per invocation.

## Configure and run

Requirements: macOS/Linux, Git, just, uv with Python 3.11+, and the selected authenticated CLI.
Set the selected provider's exact model ID in `config/ai-review/config.json`.
Empty models intentionally fail: there is no automatic provider or model selection.
Set an explicit timeout per specialist and maximum serialized snapshot size there.

```sh
just ci-ai codex main HEAD /tmp/review-codex.json
just ci-ai-claude main HEAD /tmp/review-claude.json
just ci-ai-codex main HEAD /tmp/review-codex-2.json
just ci-ai-grok main HEAD /tmp/review-grok.json
just ci-ai-agy main HEAD /tmp/review-agy.json
just ci-ai-help
```

Install at the Git repository root. Both revisions and a new report path are required. References resolve to full commit
IDs once. These commands review committed changes only: staged, unstaged, and
untracked files are not part of the review. Commit the intended change first.
The comparison is base-to-head, not an implicit merge-base comparison. The runner
never commits, pushes, updates source, or runs the project's tests. Run ordinary
`just ci` separately if the host project provides it.

The prompt includes the diff and all UTF-8 text files tracked at head, including
AGENTS.md, architecture documents and justfiles when present. It lists omitted
nontext context. Changed binary files, symlinks and submodules are unsupported and
fail rather than receive a misleading clean result. Oversized snapshots fail without
truncation; configure the limit deliberately. Repository content is sent to the
chosen provider, so only run in repositories approved for that provider. Untracked
credentials are not collected; tracked secrets are still part of the snapshot.

## Provider boundaries

- Claude: bare mode, no built-in tools or MCP configuration, no slash commands or
  session persistence. Bare mode requires `ANTHROPIC_API_KEY`; cached OAuth/keychain
  authentication is not loaded.
- Codex: read-only sandbox, no approvals, ignored user config/rules, ephemeral
  session. Existing Codex authentication remains available. Its sandbox restricts
  commands; it is not an all-tools-off mode or a confidentiality boundary.
- Grok: plain final output, no subagents/web tools, empty built-in tool allowlist,
  read-only sandbox and fresh GROK_HOME. CI authentication requires `XAI_API_KEY`.
  User state and compatibility hooks are disabled. The final text must be valid
  review JSON; unsupported output or flags fail instead of falling back.
- agy: structured streaming input/output, plan mode and terminal sandbox. These
  options alone do NOT enforce read-only behavior. A nonempty
  `isolation_commands.agy` argument array is mandatory. It names an operator-provided
  isolation launcher that receives the CLI command as subsequent arguments, inherits
  the temporary working directory/stdin, and propagates output and exit status.
  The launcher must isolate the CLI and any backend/tool processes from the host
  checkout and other writable host data, while providing the required authentication
  and model network access. A passthrough command does not satisfy this contract.

`isolation_commands` can also wrap the other providers when stronger isolation is
needed. The runner checks configuration, not the security of a custom launcher.
Do not configure untrusted command prefixes. Installation does not install CLIs,
create credentials, weaken permissions, or change ordinary CI.

Adapters target interfaces inspected on Claude 2.1.285, Codex 0.163.0, Grok 1.0.62,
and agy 1.4.2. Versions are not pinned or automatically checked. Revalidate adapters when upgrading;
unknown flags and invalid responses fail without fallback. Tests use simulated
providers; authentication/model availability
must be checked in the deployment environment.

## Review policy and output

Edit the shared policy in `config/ai-review/prompts/common.md` and the five focused
prompts beside it. Domain prompts emphasize failure modes, not presumed defects.
The schema is in `config/ai-review/schema.json`. All five sessions must return
complete reviews. Missing tools, credentials, malformed output, unsupported files,
timeouts, and incomplete sessions exit 1. No report is issued as complete on error.

A completed report records the provider, model, exact commits, snapshot hash and all
five reviews. Each finding identifies severity, file, line, title, concrete failure
scenario and evidence. `error` findings block (exit 1); warnings do not (exit 0).
Zero findings is a valid result. Reports must use new paths, so old results cannot
be mistaken for fresh ones or overwritten. Findings from multiple domains remain
separate with their provenance; a repeated finding is not counted as independent
proof. The runner validates locations and shape, not whether model reasoning is true.

Review reports are evidence to assess, not automatic permission to merge. There is
no automatic fix loop, retry, or approval. Fix justified findings, explain rejected
ones, and run again against the new commit. After three unsuccessful rounds,
reconsider the approach instead of letting author and reviewer loop indefinitely.
This round policy is guidance; this stateless runner does not enforce a round counter.

## Installation and updates

The additive installer owns `scripts/ai-review/`, `config/ai-review/`,
`docs/ai-review.md`, and `just/ai-review.just`. It imports the recipes into the
existing justfile or creates a new root justfile with dedicated help. Existing
recipes/defaults remain intact. Use `just ci-ai-help` for the added commands.
Installation refuses conflicting assets or recipe names and rolls back on failure.
It is install-only: repeating installation fails rather than overwriting customized
prompts/configuration. Apply future updates as reviewed diffs.

References: [Claude headless](https://code.claude.com/docs/en/headless),
[Codex CLI](https://developers.openai.com/codex/cli/),
[Grok scripting](https://docs.x.ai/build/cli/headless-scripting),
[agy headless](https://www.agy.dev/docs/cli/headless/).
