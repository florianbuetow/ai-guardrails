# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## 2026-09-22

### Added

- Self-contained MMIXAL CLI template with vendored MMIXware, a portable C validation driver,
  MSVC support, modular parsing/formatting/I/O example, declarative CLI and simulator-state
  tests, MMIX unit programs, real instruction coverage with an 80% floor, exact capability
  allowlists, SHA-256 vendor verification, and offline clean-rebuild lifecycle tests.

## 2026-09-20

### Added

- ARM64 macOS assembly CLI template (arm64-macos-cli-base): 100% hand-written `.S` sources for Apple Silicon, linking libSystem with raw syscalls forbidden everywhere. Guardrails are layered for a language with no semantic source analyser — ABI macro discipline, Semgrep generic policy, Clang integrated-assembler validation with `-Wa,--fatal-warnings`, object-file import layering, exact-equality import and dylib allowlists, Mach-O and signature validation, assembly unit executables, CLI black-box tests, and FileCheck assertions over real disassembly — plus the `newarm64` alias and violation tests. No coverage or mutation gate: neither has a workable equivalent for hand-written assembly.
- `test-content-tracked` check in `just ci` that fails on untracked blueprint or violation files.

### Fixed

- Fixed fresh clones missing arm64 library sources and 30 violation overlays hidden by `.gitignore`.
- Fixed arm64 template builds linking stale objects from deleted sources; missing sources now fail clearly.

## 2026-09-17 – 2026-09-18

### Added

- Node.js TypeScript CLI template (node-typescript-cli-base) with a fully local guardrail stack: oxlint, tsc, Semgrep, knip, dependency-cruiser, ts-archunit, CodeQL CLI, Gitleaks, publint, arethetypeswrong, Vitest (unit, fast-check, type, CLI black-box, packed-artifact tests), coverage and StrykerJS mutation thresholds, plus the `newnode` alias and violation tests.

### Changed

- **BREAKING:** Renamed per-template recipes and setup scripts to full blueprint names, e.g. `just test-python-cli-base`. Delete old `new*` aliases, then rerun `project-setup/setup_aliases.sh`.

### Fixed

- Fixed Kotlin K2 builds omitting unused-variable and redundant `!!` warnings by passing `-Wextra`.

### Security

- Raised GitPython to 3.1.60 in the Python template (CVE-2026-87817 and related GHSA advisories).

## 2026-09-14

### Removed

- Removed Trivy vulnerability scanning and its prerequisites from Kotlin, Scala, and Clojure templates.

## 2026-09-07

### Added

- Portable shell scripts template (shellscripts-base) with ShellCheck, Bats, ShellSpec, Kcov, cross-shell matrix, and `newshell` alias.

## 2026-08-26

### Added

- TypeScript MCP server template (mcp-server-typescript-base) on SDK v2 with protocol integration tests and `newmcp` alias.
- Scala 3 CLI template (scala-cli-base) with Scalafix, WartRemover, ArchUnit, scoverage, and `newscala` alias.
- Clojure CLI template (clojure-cli-base) with clj-kondo, Eastwood, clojure-lsp, Malli contracts, and `newclojure` alias.
- `test-prerequisites` check in `just ci` that fails when a template skips its prerequisite check.

### Changed

- Shortened the Python template uv exclude-newer window from 30 days to 7 days.
- Java Semgrep recipe now scans all of `src/`, including tests.

### Removed

- Removed Java dependency freshness and vulnerability auditing from generated projects.

### Fixed

- Raised the Python template GitPython floor to 3.1.58 so generated-project pip-audit accepts current advisories.
- Fixed Java Infer runs broken by Error Prone and `--quiet`; biabduction analysis is now enabled.

### Security

- Raised GitPython to 3.1.58 in the Python template (CVE-2026-76217 and related GHSA advisories).

## 2026-08-22 – 2026-08-24

### Changed

- Elixir template audits dependencies with `mix hex.audit` (Hex 2.5+) instead of mix_audit.
- Elixir template now fails compilation on any warning and runs Sobelow in strict mode.

### Fixed

- Raised Python template cryptography/pip floors so generated-project pip-audit accepts current advisories.
- Parse `ruff format --check` via JSON in the Python scorer (ruff's default `full` text is no longer `Would reformat:` lines).

### Security

- Raised cryptography to 50.0.0 and pip to 26.2.1 in the Python template (PYSEC-2026-3552, PYSEC-2026-3721).

## 2026-08-01 – 2026-08-05

### Changed

- Generated AGENTS.md now requires long-term, simple, modular, layered design without compatibility shims.

## 2026-07-18

### Added

- Deterministic codebase quality scorer with a `just score` target in the Python template.

### Changed

- Raised the mypy floor to 1.11 in the Python template.
- Semgrep recipe now also scans `tests/` and `pyproject.toml`.

### Fixed

- Fixed violation test isolation and retargeted two undetectable LSP fixtures.
- Restored the no-or-true shell rule in the Python template.

## 2026-06-28 – 2026-07-03

### Added

- C++ 3D game template (cpp-3dgame-base) with a Vulkan cube demo and pinned Conan 2 dependency graph.
- `gamecpp` project-setup alias and Docker-based Linux CI for the cpp-3dgame template.

### Changed

- Migrated the React/Vite template from ESLint to oxlint.
- Switched cpp-3dgame shaders to HLSL and DXC only, with Vulkan validation layers.

### Fixed

- Fixed guardrail false positives exposed by real graphics code.

## 2026-06-21

### Added

- Verified generated hooks against real template commits in the lifecycle workflow.
- Exposed template dependency pins from the lifecycle workflow.
- Dependency drift reporting in the template inventory.

### Changed

- Renamed `just info` to `just show-libs`; output now highlights template names in color.
- Dependency inventory tests now run before template generation suites in `just ci`.

### Removed

- Removed the beads issue tracker and its `.beads` directory from the repo.

### Fixed

- Fixed Java package derivation and Python pip-audit floors so generated projects pass `test-create` CI.

## 2026-06-20

### Added

- Added `test-create` target to smoke-test template creation across all blueprints.

### Changed

- Scoped C++ compiler warning errors, style logs, and tests to owned code only.
- Elixir template now owns its hook installation.
- Aligned Go linter configuration with module paths.
- Renamed TypeScript/React template from `typescript-react-base` to `react-vite-typescript-base`.
- Made Vite scaffold bootstrap non-interactive for automated template generation.
- Kotlin code-security now runs type-resolved Detekt and emits Kover XML coverage reports.

### Fixed

- Fixed Kotlin template: corrected semgrep rule label, package name rendering, and test prerequisite timeout.
- Fixed Go test-coverage to propagate failed coverage parse errors via `pipefail`.

## 2026-06-12 – 2026-06-14

### Added

- Kotlin CLI template (kotlin-cli-base) with ktlint, detekt, Kover, Konsist, and violation tests.
- TypeScript + React template (react-vite-typescript-base) with Vite, ESLint, Vitest, and Playwright.
- Project-creation aliases for every language, including `newkotlin` and `newreact`.

### Fixed

- Bounded trivy database download in Java and Kotlin code-audit to prevent CI hangs.
- Fixed TypeScript template: code-security now fails on warnings; resolved generation smoke test issues.

### Security

- Pinned pyjwt floor to 2.13.0 in Python template to satisfy pip-audit.

## 2026-05-19

### Changed

- Renamed `code-deptry` recipe to `code-machete` in Rust template.

## 2026-04-29

### Added

- Language-specific project setup scripts for all supported blueprints.

### Changed

- Set `module_path` default to project name in Go template.

## 2026-04-01

### Added

- Isolated per-rule violation tests for six Pyright strict-mode rules (missing-parameter-type, unknown-parameter-type, unknown-variable-type, unknown-member-type, unknown-argument-type, optional-call).
- IWYU prerequisite check in C++ template `check` recipe.

### Changed

- Promoted Pyright warning-level diagnostic rules to explicit `"error"` for deterministic CI failures.

### Fixed

- Fixed C++ `code-deptry` recipe to use `iwyu_tool.py` with compilation database instead of broken direct `include-what-you-use` invocation that failed to resolve system headers on macOS.

## 2026-03-30

### Added

- Supply-chain protection via `uv exclude-newer` pinning in Python template.

### Changed

- Migrated beads issue tracker to Dolt server mode.

## 2026-03-23

### Changed

- Extended no-or-true semgrep rule to scan templates and broadened repo-wide semgrep scope.

## 2026-03-22

### Added

- Violation tests for Java code-audit, Elixir no-suppression, and Elixir no-skip-tests.

### Changed

- Switched Java code-audit from Gradle dependencyUpdates to Trivy vulnerability scanning.
- Removed all `|| true` error swallowing from template justfiles.
- Standardized justfile conventions and added directory scaffolding.

## 2026-03-20

### Added

- Infer static analysis integration for Java and C++ templates.

## 2026-03-19

### Added

- 60+ violation tests across all six languages covering spell, style, typecheck, LSP, security, deptry, audit, architecture, and lint checks.
- No-suppression semgrep rules and violation tests for all languages.
- No-shellcheck-disable violation tests for all six languages.
- No-or-true semgrep rule with violation tests and `just ci` target.
- Architecture violation tests for Python, Java, Go, and Elixir.
- ex_arch_unit architecture testing for Elixir template.
- Claude Code skills and cross-language reviewer agent.
- Rust code-security violation test for cargo-geiger.
- Added `scripts/` to semgrep scan targets in all templates.

### Changed

- Hardened template justfiles and improved test runner output.
- Made C++ IWYU check strict by removing `|| true`.
- Made UBSan abort on errors with `-fno-sanitize-recover=all`.
- Added printf-over-echo rule to AGENTS.md.

### Fixed

- Fixed Go violation tests to trigger actual tool detection.
- Fixed Rust code-security recipe and added Cargo.toml overlay.
- Fixed beads pre-commit hook shim command.
- Fixed ShellCheck SC2034 warnings in test scripts.

### Removed

- Removed legacy code-validation-blueprint-guide.md.

## 2026-03-08 – 2026-03-10

### Added

- Violation testing framework that injects known-bad code and verifies each check catches it.
- 19 initial violation tests across Python, Go, Rust, Java, Elixir, and C++.
- No-skip-tests semgrep rules for all languages.
- Beads project scaffolding and issue tracker integration.
- Sub-agent delegation guide and session completion workflow.
- Semgrep no-unsafe rule for Rust template.

### Changed

- Enforced unsafe code prohibition in Rust template via cargo-geiger.
- Applied justfile convention rules to all targets.

### Fixed

- Fixed semgrep rules and optimized test runner.
- Fixed cargo-geiger emoji pattern to match actual Unicode symbols.
- Fixed README test commands to match justfile recipes.

## 2026-03-01 – 2026-03-02

### Changed

- Renamed project from "AI Templates" to "AI Guardrails" across all references, README, and AGENTS.md.

## 2026-02-28

### Added

- Java CLI template with Gradle build, 12-step CI pipeline, checkstyle, ArchUnit, and semgrep rules.
- Go CLI template with golangci-lint, arch-go architecture testing, semgrep rules, and full CI pipeline.
- Elixir OTP template with mix, Credo, Dialyzer, LSP analysis, ex_arch_unit, and custom Credo checks.
- C++ template with clang-tidy, IWYU, UBSan, and full CI pipeline.
- Rust CLI template with clippy, cargo-audit, cargo-deny, cargo-geiger, and full CI pipeline.
- Validation tools comparison table and prerequisite checks.

### Changed

- Switched from Make to Just as the command runner.
- Standardized all blueprint README.md files to canonical structure.
- Moved validation tools tables from root README to template READMEs.

### Fixed

- Fixed Go template: removed forbidigo linter and fixed destroy recipe.
- Fixed Java CLI template end-to-end CI pipeline.
- Fixed Java template test: added Homebrew OpenJDK to PATH.
- Fixed C++ template end-to-end CI pipeline.
- Fixed C++ blueprint README: corrected file names, structure, and usage instructions.
- Fixed update recipe: `$$?` expanded to PID not exit status.

### Removed

- Removed stale Elixir validation gaps design plan.

## 2026-02-25

### Added

- pytestarch architecture constraint tests for Python CLI template.

## 2026-02-11

### Added

- Recommended companion tools section in README.

## 2026-01-11 – 2026-01-12

### Added

- Semgrep rule to ban conditional assignment fallbacks.
- Cursor IDE commands directory for Python CLI template.

## 2025-12-27 – 2025-12-30

### Added

- Python CLI blueprint template with comprehensive validation suite (ruff, mypy, pyright, bandit, deptry, codespell, semgrep, pip-audit).
- No-mypy-ignore-missing-imports semgrep rule.
- Code-format as first validation step in CI targets.

### Changed

- Switched from Make to Just command runner for Python template.
- Organized documentation by moving validation guide to docs folder.

## 2025-11-04 – 2025-11-18

### Added

- Initial project setup with automated local templates and prerequisite checks.
- Git workflow guidelines: explicit file staging, push requirement, no AI attribution in commits.

[Unreleased]: https://github.com/florianbuetow/ai-guardrails/compare/39dd1db...HEAD
