# AGENTS.md

This file provides guidance to AI agents and AI-assisted development tools when working with code in this repository. This includes Claude Code, Cursor IDE, GitHub Copilot, Windsurf, and any other AI coding assistants.

## Repository Overview

This repository contains Copier templates for Python, Java, Go, Elixir, C++, and Rust that enforce strict validation guardrails on AI-generated code — catching antipatterns, suppressing silent defaults, and providing immediate feedback so AI agents write better, more maintainable code from the start.

## Core Coding Principles

These rules apply everywhere — repo scripts, justfiles, test infrastructure, and all language templates:

1. **Fail fast — never swallow errors.** Always propagate errors and exit with code 1 immediately. No silent fallbacks, no `|| true`, no ignored return codes. Use `set -e` or `&&` chaining in shell scripts.
2. **No default values — never assume missing values.** Check for required values explicitly and exit 1 if something is missing. Default values mask underlying issues and make them hard to debug.
3. **Never suppress checks with annotations.** Fix the underlying issue instead. No `@SuppressWarnings`, `# noqa`, `# type: ignore`, `#[allow(...)]`, `NOLINT`, `// noinspection`, `NOSONAR`, `@dialyzer`, `# shellcheck disable`, or any other mechanism that silences a checker.

## Git Commit Guidelines

**IMPORTANT:** When creating git commits in this repository:
- NEVER include AI attribution in commit messages
- NEVER add "Generated with [AI tool name]" or similar phrases
- NEVER add "Co-Authored-By: [AI name]" or similar attribution
- NEVER run `git add -A` or `git add .` - always stage files explicitly
- Keep commit messages professional and focused on the changes made
- Commit messages should describe what changed and why, without mentioning AI assistance
- ALWAYS run `git push` after creating a commit to push changes to the remote repository

## Current Contents

- `project-setup/setup-project-python.md` - A comprehensive guide for bootstrapping Python projects using AI agents

### Violation Tests (`violations/`)

- `violations/<language>/<rule-name>/...` contains file overlays that intentionally introduce one forbidden pattern.
- Each violation case must map to an existing guardrail rule (Semgrep or Credo) and use valid, compilable code.
- The test runner first checks a clean generated project (`just ci` must pass), then overlays violation files and expects `just ci` to fail.
- To add a new violation test:
  1. Create a new subdirectory under the target language (for example `violations/python/no-default-values/`).
  2. Add only the files that must be overlaid onto the generated project.
  3. Ensure the injected code triggers the intended rule without relying on placeholder/broken syntax.

### The Python CLI Template (`blueprints/python-cli-base`)

- Python 3.12+ with uv package management
- Project structure: src/, scripts/, data/
- Validation: ruff, mypy, pyright, bandit, semgrep, deptry, codespell, pip-audit, pytestarch, pytest
- Conventions: Justfile workflow, strict directory organization, no pip or python directly

### The Java CLI Template (`blueprints/java-cli-base`)

- Java 21+ with Gradle Kotlin DSL
- Validation: Spotless, Checkstyle, Error Prone, javac -Xlint:all -Werror, SpotBugs, semgrep, codespell, Gradle Versions Plugin, ArchUnit, JUnit 5

### The Go CLI Template (`blueprints/go-cli-base`)

- Go 1.23+ with Go modules
- Project structure: cmd/, internal/, scripts/, data/
- Validation: gofumpt, go vet, staticcheck, golangci-lint, gosec, semgrep, codespell, govulncheck, go test
- Conventions: Justfile workflow, strict error handling, no init functions, no bare returns in error funcs

### The Elixir OTP Template (`blueprints/elixir-otp-base`)

- Elixir 1.17+ with Mix build tool
- Validation: mix format, Credo, Dialyxir, mix compile --warnings-as-errors, Sobelow, mix deps.unlock --check-unused, codespell, custom Credo checks, mix audit, ExUnit

### The Rust CLI Template (`blueprints/rust-cli-base`)

- Rust 2024 edition (1.85+) with Cargo
- Project structure: src/, tests/, scripts/, data/
- Validation: rustfmt, clippy (pedantic+nursery+cargo), cargo check, cargo-geiger, cargo-machete, semgrep, codespell, cargo-deny, cargo-nextest, grcov
- Conventions: Justfile workflow, anyhow+thiserror error handling, no .unwrap(), no #[allow(...)], no unsafe

### The C++ CLI Template (`blueprints/cpp-cli-base`)

- C++23 with CMake build system
- Project structure: src/, include/, tests/, scripts/, data/
- Validation: clang-format, clang-tidy, cppcheck, flawfinder, IWYU, semgrep, codespell, GoogleTest, ASan/UBSan, lcov coverage
- Conventions: Justfile workflow, CMakePresets.json, strict compiler warnings (-Wall -Wextra -Wpedantic -Werror)

All templates emphasize creating immediately runnable projects with no placeholders, comprehensive CI pipelines, and AGENTS.md/CLAUDE.md files for AI agent guidance.

## Repository Commands

- `just ci` — Run all repo-level checks (codespell, semgrep, shellcheck) + all template tests
- `just test` — Run baseline + violation tests for all 6 languages
- `just test-<language>` — Run tests for one language (python, java, go, elixir, cpp, rust)
- `just check` — Verify required tools are installed
- `just create <template> <target-dir>` — Scaffold a new project from a blueprint

## Delegating to Sub-Agents

For large implementation tasks, long debugging sessions, or any work that benefits from a dedicated executor, read and follow [DELEGATE.md](DELEGATE.md). It covers how to spin up an isolated Codex sub-agent in a fresh tmux session, send it instructions, monitor its progress, and tear down the session when done. Use delegation whenever a task is substantial enough that running it in a separate agent avoids polluting your main context.

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
