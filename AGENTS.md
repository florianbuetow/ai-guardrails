# AGENTS.md

This file provides guidance to AI agents and AI-assisted development tools when working with code in this repository. This includes Claude Code, Cursor IDE, GitHub Copilot, Windsurf, and any other AI coding assistants.

## Repository Overview

This repository contains Copier templates for Python, Java, Go, Elixir, C++, and Rust that enforce strict validation guardrails on AI-generated code — catching antipatterns, suppressing silent defaults, and providing immediate feedback so AI agents write better, more maintainable code from the start.

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
