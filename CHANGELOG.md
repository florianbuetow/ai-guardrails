# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Promoted Pyright warning-level diagnostic rules to explicit `"error"` for deterministic CI failures.

### Added

- Isolated per-rule violation tests for six Pyright strict-mode rules (missing-parameter-type, unknown-parameter-type, unknown-variable-type, unknown-member-type, unknown-argument-type, optional-call).
- IWYU prerequisite check in C++ template `check` recipe.

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

[Unreleased]: https://github.com/florianbuetow/ai-guardrails/compare/38e431c...HEAD
