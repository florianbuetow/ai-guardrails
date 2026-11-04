# AI Review Template

Add specialist CLI reviewers to an existing project with `newaireview`, or run
`project-setup/setup-project-ai-review-claude.sh` by absolute path from that project.
The installer and runtime use Bash, jq, Git and just, with no Python or uv dependency.
Installation preserves the existing README and justfile, creates missing ones,
refuses collisions and rolls back failures. Ordinary CI remains independent.

```sh
just ci-ai                               # List providers, agents and usage
just ci-ai-codex diff                     # All reviewers, uncommitted changes
just ci-ai-claude global specs-review     # Documentation and implementation review
just ci-ai-grok commit                    # Latest commit
just ci-ai-codex commit security abc123    # Security review of a specific commit
just ci-ai-codex commit "" abc123          # All reviewers at a specific commit
```

Configure explicit models in `config/ai-review/config.json`. Reviewers run in
parallel with read tools and permission to write their assigned Markdown report
under `~/reports/ai-review/`. Independent verifier sessions assess candidate
findings. Only verified high findings or execution errors fail the command.

Prompts include shared Markdown fragments using `{{BASENAME}}`; all includes are
expanded before any CLI runs. The shared severity document defines high as a
contradiction of project intent, goals, requirements or documentation, medium as
an engineering-principle violation, and low as a minor issue.

The [README section installed into projects](README-section.md) contains complete
usage, source provenance and license notices. No license directory is buried in
the generated configuration. The supplied Codex adversarial prompt is adapted to
the package's scope, severity, permissions and report contract; extraction notes
are not included. Specs review establishes intent before correlating docs and code.

Run `just test-ai-review` for Bash installer, launcher and simulated CLI contract
tests. `just test-ai-review-live PROVIDER MODEL` is an opt-in real CLI check using
synthetic code and preserved login. It verifies reviewer/verifier reports, the
high-severity gate and unchanged fixture source files.

Claude, Codex and Grok passed this live check on 2026-11-02. See the
[installed README's validation status](README-section.md#provider-validation-and-boundaries).

`just create ai-review` is rejected: this template adds to an existing project.
