# AGENTS.md


This file provides guidance to AI agents and AI-assisted development tools when working with code in this repository. This includes Claude Code, Cursor IDE, GitHub Copilot, Windsurf, and any other AI coding assistants.

## Repository Overview

This repository contains Copier templates for Python, Java, Go, Elixir, C++, Rust, Kotlin, Scala, Clojure, TypeScript (React), TypeScript MCP servers, Node.js TypeScript CLIs, and portable shell scripts that enforce strict validation guardrails on AI-generated code — catching antipatterns, suppressing silent defaults, and providing immediate feedback so AI agents write better, more maintainable code from the start.

## Core Coding Principles

These rules apply everywhere — repo scripts, justfiles, test infrastructure, and all language templates:

1. **Fail fast — never swallow errors.** Always propagate errors and exit with code 1 immediately. No silent fallbacks, no `|| true`, no ignored return codes. Use `set -e` or `&&` chaining in shell scripts.
2. **No default values — never assume missing values.** Check for required values explicitly and exit 1 if something is missing. Default values mask underlying issues and make them hard to debug.
3. **Never suppress checks with annotations.** Fix the underlying issue instead. No `@SuppressWarnings`, `# noqa`, `# type: ignore`, `#[allow(...)]`, `NOLINT`, `// noinspection`, `NOSONAR`, `@dialyzer`, `# shellcheck disable`, or any other mechanism that silences a checker.
4. **Use `printf` for color output — never `echo`.** Some terminals won't render ANSI escape sequences with `echo`. In shell scripts and justfiles, always use `printf` for colored or formatted text output. Plain `echo ""` is acceptable only for blank-line spacing.

5. **Do not preserve backward compatibility.**
6. **Choose the simplest implementation that fully meets the current requirements.**
7. **Prefer established, well-maintained libraries over custom implementations.**

## Git Commit Guidelines

**IMPORTANT:** When creating git commits in this repository:
- NEVER include AI attribution in commit messages
- NEVER add "Generated with [AI tool name]" or similar phrases
- NEVER add "Co-Authored-By: [AI name]" or similar attribution
- NEVER run `git add -A` or `git add .` - always stage files explicitly
- Keep commit messages professional and focused on the changes made
- Commit messages should describe what changed and why, without mentioning AI assistance
- ALWAYS run `git push` after creating a commit to push changes to the remote repository
- An explicit user instruction not to commit overrides commit and push requirements only: continue authorized local edits and validation, and leave Git history untouched.

## Current Contents

- `project-setup/setup-project-python.md` - A comprehensive guide for bootstrapping Python projects using AI agents

### Violation Tests (`violations/`)

- `violations/<language>/<rule-name>/...` contains file overlays that intentionally introduce one forbidden pattern.
- Each violation case must map to an existing guardrail rule (Semgrep, Credo, or other checker) and use valid, compilable code.

**How violation testing works:**

The key principle is that we test the generated project's own CI justfile targets — the same `just code-semgrep`, `just code-security`, etc. that developers run. We're verifying that the project's built-in guardrails catch forbidden patterns, not running checks some other way.

1. **Generate** a fresh project from the template into a temp directory.
2. **Baseline** — run the project's full CI (`just ci`) on the clean project. It must pass. This confirms the template itself is valid.
3. **For each violation:**
   a. **Inject** — copy the violation's overlay files into the generated project (originals are backed up).
   b. **Expose to scanners** — established suites stage overlays for tools that require tracked files; the Scala suite deliberately scans explicit paths and performs no git staging or commits.
   c. **Run the project's targeted justfile recipe** — e.g. `just code-security`, `just code-semgrep`. The recipe name is read from a `check` file in the violation directory; if absent, defaults to `code-semgrep`.
   d. **Expect failure** — the justfile target **must exit non-zero**. If it passes, the project's guardrail failed to catch the violation and the test fails.
   e. **Restore** — put original files back and reset git state for the next test.

This is an inverted test pattern: a passing test means the project's own CI caught the bad code.

**To add a new violation test:**

1. Create a new subdirectory under the target language (for example `violations/python-cli-base/no-default-values/`).
2. Add only the files that must be overlaid onto the generated project.
3. Optionally add a `check` file containing the justfile recipe name to run (one line, e.g. `code-security`). If omitted, `code-semgrep` is used.
4. Ensure the injected code triggers the intended rule without relying on placeholder/broken syntax.

Before running a violation, confirm that its resolved recipe (`check` or the `code-semgrep` default) exists in the rendered project's justfile and exercises the intended guardrail.

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

### The C++ 3D Game Template (`blueprints/cpp-3dgame-base`)

- C++23 (or C++20) with CMake + Ninja and Conan 2 dependency management
- Project structure: src/, include/, tests/ (incl. tests/deps/ smoke tests), scripts/, data/
- Full 3D-game library stack via Conan with exact pins: SDL3, Vulkan (headers/loader/volk/vk-bootstrap/VMA; MoltenVK via brew on macOS), SPIRV-Tools/-Cross, GLM, EnTT, Jolt Physics, Recast/Detour, GameNetworkingSockets, bitsery, Opus, miniaudio, tinygltf, meshoptimizer, KTX, ozz-animation, MikkTSpace, Dear ImGui (docking), ImGuizmo, RmlUi, spdlog, fmt, Tracy, SQLite3, libpqxx, zstd, xxHash, GoogleTest
- Shaders are HLSL only, compiled to SPIR-V at build time by DXC; toktx/ktx, gltfpack, and DXC (Linux) are pinned prerequisite installs via just init
- One headless-safe GoogleTest smoke test per library in tests/deps/
- Interactive Vulkan cube demo (src/demo/, `just demo`) with mouse control, ImGui menu, debug-build validation layers (fail-fast), Tracy frame profiling, and a persisted pipeline cache
- Headless GPU rendering test (`just test-render`, in ci): offscreen render + pixel readback; Linux verification via `just test-cpp-3dgame-base-linux` (amd64 Docker container with lavapipe)
- Validation: clang-format, clang-tidy, cppcheck, flawfinder, Infer, IWYU, semgrep, codespell, GoogleTest, ASan/UBSan, lcov coverage
- Conventions: Justfile workflow, CMakePresets.json (Conan toolchains), strict compiler warnings, LLVM/Clang only

### The Kotlin CLI Template (`blueprints/kotlin-cli-base`)

- Kotlin 2.1+ on the JVM (toolchain 21+) with Gradle Kotlin DSL
- Project structure: src/main/kotlin/, src/test/kotlin/, scripts/, data/
- Validation: ktlint, detekt, kotlinc allWarningsAsErrors, semgrep, codespell, dependency-analysis, Gradle Versions Plugin, Konsist, JUnit 5, Kover
- Conventions: Justfile workflow, `./gradlew` exclusively, no `@Suppress`, no silent fallbacks, strict compiler warnings as errors

### The Scala CLI Template (`blueprints/scala-cli-base`)

- Scala 3.3 LTS on the JVM (toolchain 21) with a pinned sbt 1.13 launcher
- Architecture: `cli -> application -> domain`, enforced with ArchUnit/MUnit dependency and cycle tests
- Custom analysis: built-in Scalafix plus a project-local semantic rule tested with scalafix-testkit
- Validation: Scalafmt, Scalafix, strict scalac warnings, WartRemover, Find Security Bugs, Semgrep, sbt-explicit-dependencies, dependency locking, codespell, sbt-updates, MUnit, ArchUnit, and scoverage
- Conventions: use `./sbtw` exclusively, no check suppressions, no silent fallbacks, statement and branch coverage enforced in `just ci`

### The Clojure CLI Template (`blueprints/clojure-cli-base`)

- Clojure 1.12+ on the JVM (toolchain 21+) with Clojure CLI, `deps.edn`, and tools.build
- Architecture: `cli -> application -> domain`, enforced with clj-depend layer rules
- Validation: cljfmt, clj-kondo, project-aware clojure-lsp diagnostics and custom linters, Eastwood, Malli runtime contracts, test.check generative checks, clj-holmes, Semgrep, unused-deps, antq, codespell, Kaocha, and kaocha-cloverage
- Conventions: explicit boundary validation, Malli contracts, pure domain functions, no checker suppressions, no silent fallbacks, no `core.typed` by default

### The React Vite TypeScript Template (`blueprints/react-vite-typescript-base`)

- React + Vite + TypeScript, Node 22+/24+, npm-only tooling
- Two-phase generation: Copier provisions guardrails, then a post-task runs `npm create vite` and merges the scaffold into the project root (nothing frozen — current scaffold and tool versions at every apply; network required)
- Project structure: src/, e2e/, scripts/, data/, config/
- Validation: prettier, oxlint (react-hooks, jsx-a11y, correctness rules), tsc, semgrep, codespell, oxlint security pass (no-eval + correctness), knip, dependency-cruiser, vitest + Testing Library, Playwright, npm audit
- Conventions: Justfile workflow, npm/npx exclusively, no eslint-disable/oxlint-disable, no @ts-ignore, no skipped tests

### The TypeScript MCP Server Template (`blueprints/mcp-server-typescript-base`)

- TypeScript MCP SDK v2, Node 22.19+, ES modules, npm-only tooling, stdio transport
- Architecture: `index.ts` → `server.ts` → `tools/*` → `services/*`; business services never depend on MCP adapters
- Validation: prettier, oxlint, tsc, semgrep, codespell, knip, dependency-cruiser, Vitest, real MCP client integration tests, npm audit
- MCP guardrails: stdout is reserved for JSON-RPC, tool inputs have no silent defaults, recoverable failures return model-readable tool errors

### The Node.js TypeScript CLI Template (`blueprints/node-typescript-cli-base`)

- TypeScript on Node.js 24+, ES modules, npm-only tooling, executable `bin` plus a typed public API under `exports`
- Architecture: `index.ts -> cli/* -> application/* -> domain/*`, enforced by dependency-cruiser (import direction) and `@nielspeter/ts-archunit` (function-body rules behind `just code-architecture-deep`)
- Everything runs locally from the repository: no containers, SaaS, databases, external APIs, hosted analysis, or live vulnerability feeds (no `npm audit`)
- Validation: prettier, oxlint, tsc, semgrep, codespell, ShellCheck + shfmt, knip, dependency-cruiser, ts-archunit, CodeQL CLI, Gitleaks, publint, `@arethetypeswrong/cli`, `npm pack --dry-run`, Vitest (unit, fast-check property, `expectTypeOf` type, `child_process` CLI black-box, and packed-artifact tests), V8 coverage thresholds, StrykerJS mutation thresholds
- CLI guardrails: exit `0`/`1`/`2` for success/runtime failure/usage error, stdout reserved for results, no shell execution (`exec`, `execSync`, `shell: true` forbidden), no argv or env fallbacks

### The Portable Shell Scripts Template (`blueprints/shellscripts-base`)

- POSIX shell source with macOS and Linux compatibility checks
- Project structure: src/, test/, scripts/, data/, config/
- Validation: shfmt, ShellCheck, Bash/dash/BusyBox ash/ksh/zsh syntax checks, checkbashisms, Semgrep, codespell, executable `test/test*.sh` tests, Bats, ShellSpec, and kcov coverage
- Conventions: Justfile workflow, executable project scripts, no checker suppressions, no silent fallbacks

All templates emphasize creating immediately runnable projects with no placeholders, comprehensive CI pipelines, and AGENTS.md/CLAUDE.md files for AI agent guidance.

After changing a template, render a fresh project and inspect generated paths for duplicate trees, empty leftover directories, and unrendered template syntax before broader validation.

## Justfile Conventions

These rules apply to all justfiles — in this repository and in all generated templates:

1. **Use `printf` for colored or formatted output** — never `echo` with ANSI escape sequences, as some terminals won't render colors with `echo`. Plain `echo ""` is acceptable only for blank-line spacing.
2. **Add an empty `@echo ""` line before and after each target's command block** to visually separate output between targets.
3. **The `help` target must be a dedicated recipe** with manually written `printf` lines that group related commands and order them by typical execution flow (setup → run → code quality → testing). Never use `just --list` for help output.
4. **The default target (`_default`) must call `just help`.**
5. **Every target must end with a clear status message**: green (`\033[32m`) on success, red (`\033[31m`) on failure with `exit 1`.
6. **Composite targets (e.g. `ci`) must fail fast**: use `set -e` or `&&` chaining to ensure immediate abort on the first error.

## Repository Commands

- `just ci` — Run all repo-level checks (codespell, semgrep, shellcheck) + all template tests
- `just test` — Run baseline + violation tests for all templates
- `just test-<language>` — Run tests for one template family (python-cli-base, java-cli-base, go-cli-base, elixir-otp-base, cpp-cli-base, cpp-3dgame-base, rust-cli-base, kotlin-cli-base, scala-cli-base, clojure-cli-base, react-vite-typescript-base, mcp-server-typescript-base, node-typescript-cli-base, shellscripts-base)
- `just check` — Verify required tools are installed
- `just create <template> <target-dir>` — Scaffold a new project from a blueprint

Before concluding, verify and report evidence for every language, component, and comparison explicitly named in the user's request.

## Delegating to Sub-Agents

For large implementation tasks, long debugging sessions, or any work that benefits from a dedicated executor, read and follow [DELEGATE.md](DELEGATE.md). It covers how to spin up an isolated Codex sub-agent in a fresh tmux session, send it instructions, monitor its progress, and tear down the session when done. Use delegation whenever a task is substantial enough that running it in a separate agent avoids polluting your main context.

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

For implementation requests, diagnosis, research, review, or partial validation is not completion. Continue through the requested edits and applicable quality gates; if a gate cannot run, report the exact blocker and do not claim completion.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
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
