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
| [**python-cli-base**](blueprints/python-cli-base/) | Python 3.12+ | CLI apps with [uv](https://github.com/astral-sh/uv), [ruff](https://github.com/astral-sh/ruff), [mypy](https://mypy-lang.org/), [pyright](https://github.com/microsoft/pyright), [bandit](https://github.com/PyCQA/bandit), [semgrep](https://github.com/semgrep/semgrep), [pytest](https://pytest.org/) |
| [**java-cli-base**](blueprints/java-cli-base/) | Java 21+ | CLI apps with [Gradle](https://gradle.org/), [Spotless](https://github.com/diffplug/spotless), [Checkstyle](https://github.com/checkstyle/checkstyle), [Error Prone](https://github.com/google/error-prone), [SpotBugs](https://github.com/spotbugs/spotbugs), [JUnit 5](https://junit.org/) |
| [**go-cli-base**](blueprints/go-cli-base/) | Go 1.23+ | CLI apps with [golangci-lint](https://golangci-lint.run/), go vet, [staticcheck](https://staticcheck.dev/), [gosec](https://github.com/securego/gosec), [govulncheck](https://golang.org/x/vuln/cmd/govulncheck) |
| [**elixir-otp-base**](blueprints/elixir-otp-base/) | Elixir 1.17+ | OTP apps with [Credo](https://github.com/rrrene/credo), [Dialyxir](https://github.com/jeremyjh/dialyxir), [Sobelow](https://github.com/nccgroup/sobelow), [mix_audit](https://github.com/mirego/mix_audit), ExUnit |
| [**cpp-cli-base**](blueprints/cpp-cli-base/) | C++23 | CLI apps with [CMake](https://cmake.org/), [clang-format](https://clang.llvm.org/docs/ClangFormat.html), [clang-tidy](https://clang.llvm.org/extra/clang-tidy/), [cppcheck](https://github.com/danmar/cppcheck), [flawfinder](https://github.com/david-a-wheeler/flawfinder), [GoogleTest](https://github.com/google/googletest) |
| [**rust-cli-base**](blueprints/rust-cli-base/) | Rust 2024 | CLI apps with [clippy](https://github.com/rust-lang/rust-clippy), [cargo-geiger](https://github.com/geiger-rs/cargo-geiger), [cargo-machete](https://github.com/bnjbvr/cargo-machete), [cargo-deny](https://github.com/EmbarkStudios/cargo-deny), [cargo-nextest](https://github.com/nextest-rs/nextest), [grcov](https://github.com/mozilla/grcov) |

## Validation Tools by Language

Every template runs the same CI check categories via `just ci`. The table below shows which tool handles each check for each language.

| Check | Python | Java | Go | Elixir | C++ | Rust |
|-------|--------|------|----|--------|-----|------|
| Formatting | [ruff](https://github.com/astral-sh/ruff) | [Spotless](https://github.com/diffplug/spotless) | [gofumpt](https://github.com/mvdan/gofumpt) | mix format | [clang-format](https://clang.llvm.org/docs/ClangFormat.html) | [rustfmt](https://github.com/rust-lang/rustfmt) |
| Style | [ruff](https://github.com/astral-sh/ruff) | [Checkstyle](https://github.com/checkstyle/checkstyle) | [gofumpt](https://github.com/mvdan/gofumpt) | mix format | [clang-tidy](https://clang.llvm.org/extra/clang-tidy/) | [rustfmt](https://github.com/rust-lang/rustfmt) |
| Type checking | [mypy](https://mypy-lang.org/) | [Error Prone](https://github.com/google/error-prone) | go vet | Dialyzer | [cppcheck](https://github.com/danmar/cppcheck) | cargo check + [clippy](https://github.com/rust-lang/rust-clippy) |
| LSP analysis | [pyright](https://github.com/microsoft/pyright) | javac -Xlint:all -Werror | [staticcheck](https://staticcheck.dev/) | mix compile --warnings-as-errors | — | — |
| Security | [bandit](https://github.com/PyCQA/bandit) | [SpotBugs](https://github.com/spotbugs/spotbugs) | [gosec](https://github.com/securego/gosec) | [Sobelow](https://github.com/nccgroup/sobelow) | [flawfinder](https://github.com/david-a-wheeler/flawfinder) | [cargo-geiger](https://github.com/geiger-rs/cargo-geiger) |
| Dependency hygiene | [deptry](https://deptry.com/) | [Gradle](https://gradle.org/) buildHealth | go mod tidy | mix deps.unlock --check-unused | [IWYU](https://github.com/include-what-you-use/include-what-you-use) | [cargo-machete](https://github.com/bnjbvr/cargo-machete) |
| Spell checking | [codespell](https://github.com/codespell-project/codespell) | [codespell](https://github.com/codespell-project/codespell) | [codespell](https://github.com/codespell-project/codespell) | [codespell](https://github.com/codespell-project/codespell) | [codespell](https://github.com/codespell-project/codespell) | [codespell](https://github.com/codespell-project/codespell) |
| Custom rules | [semgrep](https://github.com/semgrep/semgrep) | [semgrep](https://github.com/semgrep/semgrep) | [semgrep](https://github.com/semgrep/semgrep) | Custom [Credo](https://github.com/rrrene/credo) checks | [semgrep](https://github.com/semgrep/semgrep) | [semgrep](https://github.com/semgrep/semgrep) |
| Vulnerability scan | [pip-audit](https://github.com/pypa/pip-audit) | [Gradle Versions Plugin](https://github.com/ben-manes/gradle-versions-plugin) | [govulncheck](https://golang.org/x/vuln/cmd/govulncheck) | mix deps.audit + hex.audit | — | [cargo-deny](https://github.com/EmbarkStudios/cargo-deny) |
| Testing | [pytest](https://pytest.org/) | [JUnit 5](https://junit.org/) | go test | ExUnit | [GoogleTest](https://github.com/google/googletest) | [cargo-nextest](https://github.com/nextest-rs/nextest) |
| Meta-linter | — | — | [golangci-lint](https://golangci-lint.run/) | [Credo](https://github.com/rrrene/credo) | — | — |
| Architecture | [pytestarch](https://github.com/zyskarch/pytestarch) | [ArchUnit](https://www.archunit.org/) | [arch-go](https://github.com/arch-go/arch-go) | [ex_arch_unit](https://hex.pm/packages/ex_arch_unit) | — | — |

See each template's README for tool details and configuration.

## Highly Recommended Companion Tools

These two tools complement AI Guardrails and are strongly recommended for any AI-assisted development workflow.

### [Guard](https://github.com/florianbuetow/guard) — Protect Files from AI Modifications

When AI agents work on your codebase, they sometimes modify unrelated files in an attempt to "fix" cascading issues. Guard lets you lock down file permissions so that the AI simply cannot touch files you want left alone. Toggle protection on individual files, collections, or use interactive mode for a fast workflow.

Use Guard alongside AI Guardrails to keep your project structure, configuration files, and critical modules safe while the AI works on the parts you want changed.

### [Claude Code Plugins](https://github.com/florianbuetow/claude-code) — Code Quality, Security, and Project Planning Skills

A collection of Claude Code plugins that bring automated design analysis, security auditing, and specification writing into your workflow:

- **SOLID Principles** — Audit any class or module against all five SOLID principles (SRP, OCP, LSP, ISP, DIP) with severity-rated findings and concrete refactoring suggestions.
- **Beyond SOLID Principles** — Architecture-level analysis covering ten principles (Separation of Concerns, DRY, Law of Demeter, Loose Coupling, KISS, YAGNI, and more) for catching structural rot across module and service boundaries.
- **Archibald** — Software architecture quality assessment across six dimensions: architectural smells, antipatterns, metrics, dependencies, risks, and technical debt.
- **K.I.S.S.** — Code and architecture simplicity analyzer covering complexity, over-abstraction, redundancy, and architectural bloat.
- **AppSec** — Comprehensive application security toolbox with 62 security skills, 8 frameworks (OWASP, STRIDE, PASTA, LINDDUN, MITRE ATT&CK), 6 red team personas, and depth modes from quick to expert.
- **Spec Writer** — Guided specification writing that produces five layered documents (Vision, Business Requirements, Software Requirements, Architecture, and Test Verification) through an interactive interview process.
- **Spec-DD** — Specification-driven development workflow orchestrator with language-aware test scenario generation, automatic test execution, and artifact traceability.
- **Explain System Tradeoffs** — Distributed system tradeoff analysis covering consistency, availability, latency, and data distribution decisions.
- **Retrospective** — Developer-AI workflow analysis with session log reviews and feedback loop integration.

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
