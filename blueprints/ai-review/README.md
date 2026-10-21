# AI Review Template

Add specialist agent reviews to an existing project, independently of its language
or whether it was created from an AI Guardrails blueprint.

```sh
cd my-project
newaireview
```

Without the alias, run
`/path/to/ai-guardrails/project-setup/setup-project-ai-review-claude.sh` from the
project root. Installation requires uv (Python 3.11+), Copier and just; it takes no
arguments. It installs review scripts, explicit model configuration, prompts,
documentation and imported just recipes. Existing justfiles are preserved; if none
exists, it creates one with a dedicated help recipe. Conflicts fail without
replacement. Failed installation rolls back its changes. Reinstallation is refused.

Configure the provider model in `config/ai-review/config.json`, authenticate the
selected CLI, then run:

```sh
just ci-ai codex main HEAD /tmp/review.json
```

Provider targets: `ci-ai-claude`, `ci-ai-codex`, `ci-ai-grok`, `ci-ai-agy`.
Every target runs separate correctness, security, performance, architecture and
tests/guardrails reviewers, using the same committed snapshot. An explicit base,
head and new report path are required. Ordinary CI remains independent.

See [installed usage and isolation requirements](template/docs/ai-review.md).
Agy requires an explicitly configured external isolation launcher; plan mode is not
an enforcement boundary. Model calls require network access and can incur charges.
No model is called during installation or offline contract tests.

Run `just test-ai-review` for installer and simulated-provider behavior tests.
`just create ai-review` is rejected because this is an additive installer, not a
standalone project template.
