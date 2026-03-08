# AI Guardrails: Project Templates with Automatic Checks for Guiding Autonomous Coding Agents

![Made with AI](https://img.shields.io/badge/Made%20with-AI-333333?labelColor=f00) ![Verified by Humans](https://img.shields.io/badge/Verified%20by-Humans-333333?labelColor=brightgreen)

Copier templates for Python, Java, Go, Elixir, C++, and Rust that enforce strict validation guardrails on AI-generated code — catching antipatterns, suppressing silent defaults, and providing immediate feedback so AI agents write better, more maintainable code from the start.

## Quick Start

**Python CLI:**

```bash
copier copy https://github.com/florianbuetow/ai-guardrails/blueprints/python-cli-base my-project
cd my-project
just init
just run
```

**Java CLI:**

```bash
copier copy https://github.com/florianbuetow/ai-guardrails/blueprints/java-cli-base my-java-project
cd my-java-project
just init
just run
```

**Go CLI:**

```bash
copier copy https://github.com/florianbuetow/ai-guardrails/blueprints/go-cli-base my-go-project
cd my-go-project
just init
just run
```

**Elixir OTP:**

```bash
copier copy https://github.com/florianbuetow/ai-guardrails/blueprints/elixir-otp-base my-elixir-project
cd my-elixir-project
just init
just run
```

**C++ CLI:**

```bash
copier copy https://github.com/florianbuetow/ai-guardrails/blueprints/cpp-cli-base my-cpp-project
cd my-cpp-project
just init
just run
```

**Rust CLI:**

```bash
copier copy https://github.com/florianbuetow/ai-guardrails/blueprints/rust-cli-base my-rust-project
cd my-rust-project
just init
just run
```

## Features

- **Multi-step CI pipelines** with fail-fast behavior across all templates
- **Pre-commit hooks** run full CI validation automatically before each commit
- **Custom semgrep rules** ban default values, type suppressions, and sneaky fallback patterns
- **AGENTS.md** provides AI assistants with project conventions and development rules
- **Just task runner** with recipes for common tasks (init, run, test, ci, destroy)
- **Test infrastructure** with coverage thresholds and quality gates

## Available Templates

| Template | Language | Description |
|----------|----------|-------------|
| [**python-cli-base**](blueprints/python-cli-base/) | Python 3.12+ | CLI apps with uv, ruff, mypy, pyright, bandit, semgrep, pytest |
| [**java-cli-base**](blueprints/java-cli-base/) | Java 21+ | CLI apps with Gradle, Spotless, Checkstyle, Error Prone, SpotBugs, JUnit 5 |
| [**go-cli-base**](blueprints/go-cli-base/) | Go 1.23+ | CLI apps with golangci-lint, go vet, staticcheck, gosec, govulncheck |
| [**elixir-otp-base**](blueprints/elixir-otp-base/) | Elixir 1.17+ | OTP apps with Credo, Dialyxir, Sobelow, mix_audit, ExUnit |
| [**cpp-cli-base**](blueprints/cpp-cli-base/) | C++23 | CLI apps with CMake, clang-format, clang-tidy, cppcheck, flawfinder, GoogleTest |
| [**rust-cli-base**](blueprints/rust-cli-base/) | Rust 2024 | CLI apps with clippy, cargo-geiger, cargo-machete, cargo-deny, cargo-nextest, grcov |

## Validation Tools by Language

Every template runs the same CI check categories via `just ci`. The table below shows which tool handles each check for each language.

| Check | Python | Java | Go | Elixir | C++ | Rust |
|-------|--------|------|----|--------|-----|------|
| Formatting | ruff | Spotless | gofumpt | mix format | clang-format | rustfmt |
| Style | ruff | Checkstyle | gofumpt | mix format | clang-tidy | rustfmt |
| Type checking | mypy | Error Prone | go vet | Dialyzer | cppcheck | cargo check + clippy |
| LSP analysis | pyright | javac -Xlint:all -Werror | staticcheck | mix compile --warnings-as-errors | — | — |
| Security | bandit | SpotBugs | gosec | Sobelow | flawfinder | cargo-geiger |
| Dependency hygiene | deptry | Gradle buildHealth | go mod tidy | mix deps.unlock --check-unused | IWYU | cargo-machete |
| Spell checking | codespell | codespell | codespell | codespell | codespell | codespell |
| Custom rules | semgrep | semgrep | semgrep | Custom Credo checks | semgrep | semgrep |
| Vulnerability scan | pip-audit | Gradle Versions Plugin | govulncheck | mix deps.audit + hex.audit | — | cargo-deny |
| Testing | pytest | JUnit 5 | go test | ExUnit | GoogleTest | cargo-nextest |
| Meta-linter | — | — | golangci-lint | Credo | — | — |
| Architecture | pytestarch | ArchUnit | arch-go | — | — | — |

See each template's README for tool details and configuration, or [code-validation-blueprint-guide.md](docs/code-validation-blueprint-guide.md) for semgrep rules.

## Highly Recommended Companion Tools

These two tools complement AI Guardrails and are strongly recommended for any AI-assisted development workflow.

### [Guard](https://github.com/florianbuetow/guard) — Protect Files from AI Modifications

When AI agents work on your codebase, they sometimes modify unrelated files in an attempt to "fix" cascading issues. Guard lets you lock down file permissions so that the AI simply cannot touch files you want left alone. Toggle protection on individual files, collections, or use interactive mode for a fast workflow.

Use Guard alongside AI Guardrails to keep your project structure, configuration files, and critical modules safe while the AI works on the parts you want changed.

### [Claude Code Plugins](https://github.com/florianbuetow/claude-code) — Code Quality and Project Planning Skills

A collection of three Claude Code plugins that bring automated design analysis and specification writing into your workflow:

- **SOLID Principles** — Audit any class or module against all five SOLID principles (SRP, OCP, LSP, ISP, DIP) with severity-rated findings and concrete refactoring suggestions.
- **Beyond SOLID Principles** — Architecture-level analysis covering ten principles (Separation of Concerns, DRY, Law of Demeter, Loose Coupling, KISS, YAGNI, and more) for catching structural rot across module and service boundaries.
- **Spec Writer** — Guided specification writing that produces five layered documents (Vision, Business Requirements, Software Requirements, Architecture, and Test Verification) through an interactive interview process.

Use these plugins after scaffolding a project with AI Guardrails to maintain code quality as the codebase grows and to plan new features with proper specifications before writing code.

## Prerequisites

- **git** - Version control system
- **just** - Command runner ([installation guide](https://github.com/casey/just#installation))
- **copier** - Template engine ([installation guide](https://copier.readthedocs.io/))

Each template has its own language-specific prerequisites. See the template READMEs for details:
[Python](blueprints/python-cli-base/) | [Java](blueprints/java-cli-base/) | [Go](blueprints/go-cli-base/) | [Elixir](blueprints/elixir-otp-base/) | [C++](blueprints/cpp-cli-base/) | [Rust](blueprints/rust-cli-base/)

## Installation

Clone this repository:

```bash
git clone https://github.com/florianbuetow/ai-guardrails.git
cd ai-guardrails
```

## Usage

### Creating a New Project

**Method 1: Using the just command (recommended)**

```bash
cd ai-guardrails
just create python-cli-base ~/projects/my-awesome-project
cd ~/projects/my-awesome-project
just init
just run
```

The `just create` command takes two arguments:
1. Template name (e.g., `python-cli-base`, `java-cli-base`, `go-cli-base`, `elixir-otp-base`, `cpp-cli-base`, or `rust-cli-base`)
2. Target directory (absolute or relative path where the project will be created)

**Method 2: Using Copier directly**

```bash
copier copy /path/to/ai-guardrails/blueprints/python-cli-base my-awesome-project
cd my-awesome-project
just init
just run
```

## Development

### Run Tests

```bash
cd ai-guardrails
just test          # Run all language suites (baseline + violation tests)
just test-python   # Run Python baseline + violation tests
just test-java     # Run Java baseline + violation tests
just test-go       # Run Go baseline + violation tests
just test-elixir   # Run Elixir baseline + violation tests
just test-cpp      # Run C++ baseline + violation tests
just test-rust     # Run Rust baseline + violation tests
```

Each language suite now runs two phases:
1. Baseline test: generate a clean project and verify `just ci` succeeds.
2. Violation tests: for every folder under `violations/<language>/`, generate a fresh project, confirm baseline `just ci` passes, overlay the violation files, then assert `just ci` fails.

This verifies both directions of the guardrails: valid generated projects pass, and known-bad patterns are rejected.

### Updating the Template Repository

To get the latest template features, configurations, and fixes:

```bash
cd ai-guardrails
just update
```

This updates the ai-guardrails repository itself (via `git pull`). Existing projects created from the template are not affected.

## Repository Structure

```
ai-guardrails/
├── blueprints/                                 # Copier-based project templates
│   ├── python-cli-base/                       # Python CLI template (README, copier.yml, template/)
│   ├── java-cli-base/                         # Java CLI template
│   ├── go-cli-base/                           # Go CLI template
│   ├── elixir-otp-base/                       # Elixir OTP template
│   ├── cpp-cli-base/                          # C++ CLI template
│   └── rust-cli-base/                         # Rust CLI template
├── tests/
│   ├── run-tests.sh                           # Unified test entry point
│   ├── lib/                                   # Shared test helpers and runner logic
│   │   ├── helpers.sh
│   │   └── runner.sh
│   └── languages/                             # Per-language template config + prerequisites
│       ├── python.sh
│       ├── java.sh
│       ├── go.sh
│       ├── elixir.sh
│       ├── cpp.sh
│       └── rust.sh
├── violations/                                 # Violation overlays used to force CI failures
│   ├── python/
│   ├── java/
│   ├── go/
│   ├── elixir/
│   ├── cpp/
│   └── rust/
├── config/                                     # Shared validation configs (semgrep, codespell)
├── docs/                                       # Documentation
├── justfile                                    # Quick setup commands
├── AGENTS.md                                   # Guidance for AI agents
└── README.md                                   # This file
```

## Contributing

Contributions are welcome! When adding features or fixes:

1. Add tests in `tests/` directory
2. Run `just test` to verify the template works correctly
3. Update documentation as needed
4. Follow the patterns established in the existing template
