# Python CLI Base Template

Production-ready Copier template for Python CLI applications with full validation infrastructure.

## Features

- **Python 3.12+** with uv package management
- **Just task runner** for all commands
- **Pre-commit hooks** with CI checks
- **Comprehensive AGENTS.md** for AI-assisted development
- **Git worktree workflow** support

### Validation Tools

| Tool | Purpose | Why It's Used |
|------|---------|---------------|
| **ruff** | Linting and formatting | Fast Python linter and formatter - replaces flake8, isort, and black |
| **mypy** | Type checking | Static type checker for gradual typing - catches type errors before runtime |
| **pyright** | Strict type checking | Microsoft's LSP-based type checker - stricter than mypy, catches more edge cases |
| **bandit** | Security scanning | Finds common security issues in Python code (SQL injection, hardcoded passwords, etc.) |
| **semgrep** | Custom static analysis | Pattern-based code scanning - enforces project-specific rules |
| **deptry** | Dependency hygiene | Finds unused dependencies and missing imports |
| **codespell** | Spell checking | Catches typos in code, comments, and documentation |
| **pip-audit** | Vulnerability scanning | Scans dependencies for known security vulnerabilities |
| **pytestarch** | Architecture constraints | Enforces import boundaries between layers - prevents architectural erosion |
| **pytest** | Testing framework | Unit testing with fixtures, parameterization, and coverage |

## Template Structure

```
blueprints/python-cli-base/
├── copier.yml                          # Template configuration
├── README.md                           # This file
└── template/                           # Template files
    ├── .gitignore.template
    ├── .python-version.template
    ├── pyproject.toml.template
    ├── pyrightconfig.json.template
    ├── .pre-commit-config.yaml.template
    ├── justfile.template
    ├── README.md.template
    ├── AGENTS.md.template
    ├── CLAUDE.md -> AGENTS.md         # Symlink (created via _tasks)
    ├── .cursor/
    │   └── commands/
    │       └── doc-statemachine.md    # Cursor AI command for state machine diagrams
    ├── src/
    │   ├── {{package_name}}/
    │   │   └── __init__.py
    │   └── main.py.template
    ├── tests/
    │   └── __init__.py
    ├── scripts/
    ├── data/
    │   ├── input/
    │   └── output/
    └── config/
        ├── semgrep/
        │   ├── no-default-values.yml
        │   ├── no-sneaky-fallbacks.yml
        │   ├── no_type_suppression.yml
        │   ├── no-noqa.yml
        │   ├── no-mypy-ignore-missing-imports.yml
        │   └── python-constants.yml
        └── codespell/
            └── ignore.txt
```

## Usage

### Via just create

```bash
cd /path/to/ai-guardrails
just create python-cli-base my-project
```

### Direct Copier usage

```bash
copier copy blueprints/python-cli-base my-project
cd my-project
just init
just run
```

## Template Questions

The template will ask:

- **project_name**: Project name (e.g., my-cli-tool)
- **package_name**: Python package name (e.g., my_cli_tool)
- **project_description**: Short description
- **python_version**: Minimum Python version (3.12 or 3.13)
- **author_name**: Author name
- **author_email**: Author email
- **coverage_threshold**: Code coverage threshold (0-100, default 80)

## Generated Project Features

Projects created from this template include:

- **Strict Python execution**: Only via `uv run` (never `python` directly)
- **Complete validation suite**: All tools configured in pyproject.toml
- **Just recipes**: init, run, destroy, code-*, test, ci, ci-quiet
- **Pre-commit hooks**: Runs `just ci-quiet` on commit
- **AI agent rules**: AGENTS.md with strict development guidelines
- **Git commit rules**: No AI attribution, explicit file staging
- **Semgrep rules**: Enforce explicit configuration, no defaults, no type suppression
- **Directory structure**: src/, tests/, scripts/, data/

## Semgrep Rules

| Rule | Purpose |
|------|---------|
| `no-default-values` | Bans default parameter values, `dict.get()` with defaults, Pydantic `Field(default=)` -- require explicit arguments |
| `no-sneaky-fallbacks` | Bans conditional expression fallbacks, `or` operator fallbacks, `getattr()` with defaults -- no silent defaults |
| `no_type_suppression` | Bans `# type: ignore`, `# mypy: ignore-errors`, `# pyright: ignore` -- fix type issues instead of suppressing |
| `no-noqa` | Bans `# noqa` comments -- fix lint issues instead of suppressing |
| `no-mypy-ignore-missing-imports` | Bans `ignore_missing_imports = true` in pyproject.toml -- require proper type stubs |
| `python-constants` | Bans module-level primitive constant declarations -- restrict to main blocks or config files |

## Requirements

- **Python 3.12+**
- **uv** - Python package manager
- **just** - Command runner
- **copier** - Template engine
- **git** - Version control

## Testing the Template

To verify the template generates correctly:

```bash
cd /path/to/ai-guardrails
just test
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
2. Test with: `just test` (from repository root)
3. Verify generated project works
4. Commit changes

## Sources

Based on:
- [mjun0812/python-copier-template](https://github.com/mjun0812/python-copier-template)
- ai-guardrails/project-setup/setup-project-python.md
