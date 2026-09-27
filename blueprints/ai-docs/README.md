# AI Docs Template

Copier blueprint for an agent-oriented knowledge base, following the layout from
OpenAI's [Harness engineering](https://openai.com/index/harness-engineering/) article.
It is not tied to a programming language and does not create a project: it adds the
knowledge base to the current directory of an existing project.

```sh
cd my-project
newaidocs
```

Without the alias, run `project-setup/setup-project-ai-docs-claude.sh` from the
project directory. It takes no arguments and:

- exits with code 1, changing nothing, when `docs` or `ARCHITECTURE.md` already
  exists, or when `AGENTS.md` exists but is not a regular file;
- copies [`template/`](template/) into the current directory: `docs/` and a root
  `ARCHITECTURE.md` for the project's code map;
- appends [`agents-section.md`](agents-section.md) to `AGENTS.md`, creating the file if
  it is missing. That section teaches agents the layout: the purpose of every folder
  and file, and when to read or update it;
- then, when git is installed and the directory is inside a git work tree, runs
  `git check-ignore` on every installed file. If git ignores any of them, it prints a
  warning with the matching ignore rules and exits with code 1.

Run `just test-ai-docs` to test the installer and the template layout.
