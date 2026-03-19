# Elixir OTP Base Template

Production-ready Copier template for Elixir OTP applications with full validation infrastructure.

## Features

- **Elixir 1.17+** with Mix build tool
- **Just task runner** for all commands
- **Git hooks** via git_hooks hex package
- **Comprehensive AGENTS.md** for AI-assisted development
- **Git worktree workflow** support

### Validation Tools

| Tool | Purpose | Why It's Used |
|------|---------|---------------|
| **mix format** | Formatting | Built-in code formatter - enforces consistent Elixir code style |
| **Credo** | Linting | Static analysis for code consistency, readability, and refactoring opportunities (strict mode) |
| **Dialyxir** | Type checking | Erlang Dialyzer wrapper - catches type errors, unreachable code, and spec violations |
| **mix compile** | LSP analysis | Compiler warnings-as-errors catches unused variables, imports, aliases, and deprecated calls |
| **Sobelow** | Security scanning | Finds security issues in Elixir code (SQL injection, XSS, directory traversal, etc.) |
| **mix deps** | Dependency hygiene | Detects unused dependencies and lock file drift |
| **codespell** | Spell checking | Catches typos in code, comments, and documentation |
| **Custom Credo checks** | Custom rules | Bans default parameters, fallback operators, Map.get defaults, and Dialyzer suppression |
| **mix_audit** | Vulnerability scanning | Scans Hex dependencies for known security vulnerabilities |
| **ExUnit** | Testing framework | Built-in testing with coverage support and async test execution |
| **ex_arch_unit** | Architecture testing | Enforces module dependency boundaries and detects circular dependencies |

## Template Structure

```
blueprints/elixir-otp-base/
├── copier.yml                          # Template configuration
├── README.md                           # This file
└── template/                           # Template files
    ├── .credo.exs
    ├── .formatter.exs
    ├── .gitignore.template
    ├── AGENTS.md.template
    ├── arch.exs.template
    ├── CLAUDE.md -> AGENTS.md         # Symlink (created via _tasks)
    ├── README.md.template
    ├── justfile.template
    ├── mix.exs.template
    ├── config/
    │   ├── config.exs.template
    │   └── codespell/
    │       └── ignore.txt
    ├── lib/
    │   ├── {{app_name}}.ex.template
    │   └── credo/
    │       └── check/
    │           ├── no_default_parameter_values.ex
    │           ├── no_dialyzer_suppress.ex
    │           ├── no_fallback_operator.ex
    │           └── no_map_get_default.ex
    └── test/
        ├── architecture/
        │   └── architecture_test.exs.template
        ├── test_helper.exs
        └── {{app_name}}_test.exs.template
```

## Usage

### Via just create

```bash
cd /path/to/ai-guardrails
just create elixir-otp-base my-elixir-app
```

### Direct Copier usage

```bash
copier copy blueprints/elixir-otp-base my-elixir-app
cd my-elixir-app
just init
just run
```

## Template Questions

The template will ask:

- **project_name**: Project name (e.g., my-otp-app)
- **app_name**: Elixir application name (e.g., my_otp_app)
- **module_name**: Module name (e.g., MyOtpApp)
- **project_description**: Short description
- **elixir_version**: Minimum Elixir version (1.17 or 1.18)
- **author_name**: Author name
- **coverage_threshold**: Code coverage threshold (0-100, default 80)

## Generated Project Features

Projects created from this template include:

- **Mix build system**: Standard Elixir project with OTP application structure
- **Complete validation suite**: Credo, Dialyxir, Sobelow, mix_audit, codespell
- **Custom Credo checks**: Bans default parameters, fallback operators, Map.get defaults, Dialyzer suppression
- **Just recipes**: init, run, destroy, code-*, test, ci, ci-quiet
- **Git hooks**: Runs `just ci-quiet` on commit via git_hooks
- **AI agent rules**: AGENTS.md with strict development guidelines
- **Git commit rules**: No AI attribution, explicit file staging
- **Architecture testing**: ex_arch_unit layer boundary enforcement and cycle detection
- **Directory structure**: lib/, test/, config/

## Custom Credo Checks

| Check | Purpose |
|-------|---------|
| `no_default_parameter_values` | Bans default values in function parameters -- require explicit arguments |
| `no_dialyzer_suppress` | Bans `@dialyzer` attributes -- fix type issues instead of suppressing |
| `no_fallback_operator` | Bans `||` fallback operator for default values -- handle missing data explicitly |
| `no_map_get_default` | Bans `Map.get/3` with default values -- fail on missing keys instead |

## Requirements

- **Elixir 1.17+**
- **Erlang/OTP 26+**
- **just** - Command runner
- **copier** - Template engine
- **git** - Version control
- **codespell** - Spell checker (optional)

## Testing the Template

To verify the template generates correctly:

```bash
cd /path/to/ai-guardrails
just test-elixir
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
cd my-elixir-app/main
copier update
```

## Development

To modify this template:

1. Edit files in `template/` directory
2. Test with: `just test-elixir` (from repository root)
3. Verify generated project works
4. Commit changes

## Sources

Based on:
- [elixir-lang/elixir](https://github.com/elixir-lang/elixir)
- ai-guardrails/blueprints/python-cli-base
