# Rust CLI Base Template

Production-ready Copier template for Rust CLI applications with full validation infrastructure.

## Features

- **Rust 2024 edition** (1.85+) with Cargo build system
- **Just task runner** for all commands
- **Pre-commit hooks** with CI checks
- **Comprehensive AGENTS.md** for AI-assisted development
- **Git worktree workflow** support

### Validation Tools

| Tool | Purpose | Why It's Used |
|------|---------|---------------|
| **rustfmt** | Formatting | Standard Rust formatter - enforces consistent code style |
| **clippy** | Linting | Pedantic + nursery + cargo lint groups - catches subtle bugs and anti-patterns |
| **cargo check** | Type checking | Fast compilation check across all targets without producing binaries |
| **cargo-geiger** | Security scanning | Detects unsafe code in the entire dependency tree |
| **cargo-machete** | Dependency hygiene | Finds unused dependencies in Cargo.toml |
| **semgrep** | Custom static analysis | Pattern-based code scanning - enforces project-specific error handling rules |
| **codespell** | Spell checking | Catches typos in code, comments, and documentation |
| **cargo-deny** | Vulnerability scanning | Checks advisories, license compliance, and dependency bans |
| **cargo-nextest** | Testing framework | Fast, parallel test runner with better output than cargo test |
| **grcov** | Coverage reporting | Source-based code coverage using LLVM instrumentation |

## Template Structure

```
blueprints/rust-cli-base/
├── copier.yml                          # Template configuration
├── README.md                           # This file
└── template/                           # Template files
    ├── Cargo.toml.template
    ├── rustfmt.toml
    ├── deny.toml
    ├── .gitignore.template
    ├── .semgrepignore.template
    ├── .pre-commit-config.yaml.template
    ├── justfile.template
    ├── README.md.template
    ├── AGENTS.md.template
    ├── CLAUDE.md -> AGENTS.md         # Symlink (created via _tasks)
    ├── src/
    │   ├── main.rs.template
    │   └── lib.rs.template
    ├── tests/
    │   └── integration_test.rs.template
    ├── scripts/
    ├── data/
    │   ├── input/
    │   └── output/
    └── config/
        ├── semgrep/
        │   ├── no-unwrap.yml
        │   ├── no-expect-without-context.yml
        │   ├── no-silent-error-discard.yml
        │   ├── no-allow-attributes.yml
        │   └── no-default-fallbacks.yml
        └── codespell/
            └── ignore.txt
```

## Usage

### Via just create

```bash
cd /path/to/ai-guardrails
just create rust-cli-base my-project
```

### Direct Copier usage

```bash
copier copy blueprints/rust-cli-base my-project
cd my-project
just init
just run
```

## Template Questions

The template will ask:

- **project_name**: Project name (e.g., my-rust-tool)
- **crate_name**: Rust crate name (e.g., my_rust_tool)
- **project_description**: Short description
- **author_name**: Author name
- **author_email**: Author email
- **coverage_threshold**: Code coverage threshold (0-100, default 80)

## Generated Project Features

Projects created from this template include:

- **Strict Rust configuration**: Clippy pedantic + nursery + cargo lints, unsafe code denied
- **Error handling patterns**: anyhow + thiserror with strict enforcement via semgrep
- **Complete validation suite**: 10 checks covering formatting, linting, security, and testing
- **Just recipes**: init, run, destroy, code-*, test, ci, ci-quiet
- **Pre-commit hooks**: Runs `just ci-quiet` on commit
- **AI agent rules**: AGENTS.md with strict development guidelines
- **Git commit rules**: No AI attribution, explicit file staging
- **Semgrep rules**: Enforce explicit error handling, ban unwrap/allow/silent discards
- **Directory structure**: src/, tests/, scripts/, data/

## Semgrep Rules

| Rule | Purpose |
|------|---------|
| `no-unwrap` | Bans `.unwrap()` in src/ -- use `?` operator instead |
| `no-expect-without-context` | Bans `.expect("")` with empty message |
| `no-silent-error-discard` | Bans `let _ = expr;` -- handle Results explicitly |
| `no-allow-attributes` | Bans `#[allow(...)]` -- fix issues or use `#[expect(...)]` |
| `no-default-fallbacks` | Bans `.unwrap_or()` / `.unwrap_or_default()` / `.unwrap_or_else()` |

## Requirements

- **Rust 1.85+** (2024 edition)
- **just** - Command runner
- **copier** - Template engine
- **git** - Version control

## Testing the Template

To verify the template generates correctly:

```bash
cd /path/to/ai-guardrails
just test-rust
```

This will:
1. Generate a test project in a temp directory
2. Verify all files are created
3. Verify CLAUDE.md symlink is correct
4. Run `just init`, `just run`, `just ci`, `just ci-quiet`, `just destroy` in the generated project
5. Clean up temp directory

## Updating Generated Projects

Projects can be updated when the template changes:

```bash
cd my-project/main
copier update
```

## Development

To modify this template:

1. Edit files in `template/` directory
2. Test with: `just test-rust` (from repository root)
3. Verify generated project works
4. Commit changes

## Sources

Based on:
- [rust-lang/cargo](https://github.com/rust-lang/cargo)
- ai-guardrails/blueprints/python-cli-base
