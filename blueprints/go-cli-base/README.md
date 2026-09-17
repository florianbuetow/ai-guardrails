# Go CLI Base Template

Production-ready Copier template for Go CLI applications with full validation infrastructure.

## Features

- **Go 1.23+** with standard Go modules
- **Just task runner** for all commands
- **Pre-commit hooks** with CI checks
- **Comprehensive AGENTS.md** for AI-assisted development
- **Git worktree workflow** support

### Validation Tools

| Tool | Purpose | Why It's Used |
|------|---------|---------------|
| **gofumpt** | Formatting | Stricter gofmt - enforces consistent formatting beyond standard gofmt |
| **go vet** | Static analysis | Built-in tool that catches suspicious constructs (printf args, struct tags, etc.) |
| **staticcheck** | Strict analysis | LSP-based checker - catches unused code, deprecated APIs, and subtle bugs |
| **golangci-lint** | Meta-linter | Runs 50+ linters in parallel - single tool for comprehensive code quality |
| **gosec** | Security scanning | Finds security issues (SQL injection, hardcoded credentials, weak crypto, etc.) |
| **semgrep** | Custom static analysis | Pattern-based code scanning - enforces project-specific rules |
| **codespell** | Spell checking | Catches typos in code, comments, and documentation |
| **govulncheck** | Vulnerability scanning | Scans dependencies for known security vulnerabilities using Go vulnerability database |
| **go test** | Testing framework | Built-in testing with race detection, coverage, and benchmarks |
| **arch-go** | Architecture testing | Validates package dependencies, naming, content, and function rules via arch-go.yml |

## Template Structure

```
blueprints/go-cli-base/
├── copier.yml                          # Template configuration
├── README.md                           # This file
└── template/                           # Template files
    ├── .gitignore.template
    ├── .golangci.yml
    ├── .pre-commit-config.yaml.template
    ├── .semgrepignore.template
    ├── AGENTS.md.template
    ├── CLAUDE.md -> AGENTS.md         # Symlink (created via _tasks)
    ├── README.md.template
    ├── arch-go.yml
    ├── go.mod.template
    ├── justfile.template
    ├── cmd/
    │   └── main.go.template
    ├── internal/
    │   └── app/
    │       ├── app.go.template
    │       └── app_test.go.template
    ├── scripts/
    ├── data/
    │   ├── input/
    │   └── output/
    └── config/
        ├── semgrep/
        │   ├── no-bare-return-in-error-func.yml
        │   ├── no-build-ignore.yml
        │   ├── no-error-swallowing.yml
        │   ├── no-init-functions.yml
        │   └── no-nolint-without-justification.yml
        └── codespell/
            └── ignore.txt
```

## Usage

### Via just create

```bash
cd /path/to/ai-guardrails
just create go-cli-base my-project
```

### Direct Copier usage

```bash
copier copy blueprints/go-cli-base my-project
cd my-project
just init
just run
```

## Template Questions

The template will ask:

- **project_name**: Project name (e.g., my-cli-tool)
- **module_path**: Go module path (e.g., github.com/user/project)
- **project_description**: Short description
- **go_version**: Minimum Go version (1.23 or 1.24)
- **author_name**: Author name
- **author_email**: Author email
- **coverage_threshold**: Code coverage threshold (0-100, default 80)

## Generated Project Features

Projects created from this template include:

- **Standard Go project layout**: cmd/, internal/, scripts/, data/
- **Go modules**: Dependency management via go.mod
- **Complete validation suite**: Linting, formatting, vetting, vulnerability scanning
- **Just recipes**: init, run, destroy, code-*, test, ci, ci-quiet
- **Pre-commit hooks**: Runs `just ci-quiet` on commit
- **AI agent rules**: AGENTS.md with strict development guidelines
- **Git commit rules**: No AI attribution, explicit file staging
- **Semgrep rules**: Enforce explicit error handling, ban init functions, require nolint justifications
- **Directory structure**: cmd/, internal/, scripts/, data/

## Semgrep Rules

| Rule | Purpose |
|------|---------|
| `no-bare-return-in-error-func` | Bans bare `return` in functions with named error returns -- return errors explicitly |
| `no-build-ignore` | Bans `//go:build ignore` -- remove excluded files instead of ignoring them |
| `no-error-swallowing` | Bans assigning errors to `_` -- handle all errors explicitly |
| `no-init-functions` | Bans `init()` functions -- use explicit initialization with clear ordering |
| `no-nolint-without-justification` | Bans bare `//nolint` -- require explicit linter name and justification |

## Requirements

- **Go 1.23+**
- **just** - Command runner
- **copier** - Template engine
- **git** - Version control

## Testing the Template

To verify the template generates correctly:

```bash
cd /path/to/ai-guardrails
just test-go-cli-base
```

This will:
1. Generate a test project in a temp directory
2. Verify all expected files are created
3. Verify CLAUDE.md symlink is correct
4. Run `just init`, `just run`, `just ci`, `just ci-quiet`, and `just destroy`
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
2. Test with: `just test-go-cli-base` (from repository root)
3. Verify generated project works
4. Commit changes

## Sources

Based on:
- [golang-standards/project-layout](https://github.com/golang-standards/project-layout)
- ai-guardrails/blueprints/python-cli-base
