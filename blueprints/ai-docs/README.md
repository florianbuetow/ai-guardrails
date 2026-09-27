# AI Docs Template

Copier blueprint for an agent-oriented knowledge base, following the layout from
OpenAI's [Harness engineering](https://openai.com/index/harness-engineering/) article.
It is not tied to a programming language and does not create a project: it adds the
knowledge base to the current directory of an existing project.

```sh
cd my-project
newaidocs
```

Without the alias, run `/path/to/ai-guardrails/project-setup/setup-project-ai-docs-claude.sh`
from the project directory. It takes no arguments and:

- exits with code 1, changing nothing, when `docs` or `ARCHITECTURE.md` already
  exists, when `AGENTS.md` is a symlink, not a regular file, or not writable, or when
  the directory is not writable;
- copies [`template/`](template/) into the current directory: `docs/`, whose
  [`README.md`](template/docs/README.md) explains the layout as the article describes
  it, and a root `ARCHITECTURE.md` for the project's code map;
- appends [`agents-section.md`](agents-section.md) to `AGENTS.md`, creating the file if
  it is missing. That section maps every folder and file with its purpose and when to
  read or update it;
- rolls back its changes if copying or the `AGENTS.md` update fails, so the run can be
  retried;
- then, when git is installed and the directory is inside a git work tree, runs
  `git check-ignore` on every installed file. If git ignores any of them, it prints a
  warning naming what is ignored and the matching ignore rules, and exits with code 1.

Run `just test-ai-docs` to test the installer and the template layout.
