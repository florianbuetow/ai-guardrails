# Java CLI Base Template

Production-ready Copier template for Java CLI applications with full validation infrastructure.

## Features

- **Java 21+** with Gradle Kotlin DSL build system
- **Gradle Wrapper** included for reproducible builds
- **Just task runner** for all commands
- **Pre-commit hooks** with CI checks
- **Comprehensive AGENTS.md** for AI-assisted development
- **Git worktree workflow** support

### Validation Tools

| Tool | Purpose | Why It's Used |
|------|---------|---------------|
| **Spotless** | Formatting | Applies google-java-format for consistent code style |
| **Checkstyle** | Code style | Enforces Google Java Style Guide conventions |
| **Error Prone** | Bug detection | Google's compile-time checker - catches common Java mistakes |
| **javac -Xlint:all -Werror** | LSP-equivalent checks | Strict compiler warnings catch unused imports, variables, deprecation, unchecked casts |
| **SpotBugs** | Security scanning | Finds security issues with Find Security Bugs plugin |
| **semgrep** | Custom static analysis | Pattern-based code scanning - enforces project-specific rules |
| **Dependency Analysis** | Dependency hygiene | Detects unused and undeclared dependencies |
| **codespell** | Spell checking | Catches typos in code, comments, and documentation |
| **Gradle Versions Plugin** | Dependency version audit | Detects outdated dependencies with available updates |
| **ArchUnit** | Architecture constraints | Enforces package structure and import rules - prevents architectural erosion |
| **JUnit 5 + JaCoCo** | Testing and coverage | Unit testing with coverage thresholds |

## Template Structure

```
blueprints/java-cli-base/
├── copier.yml                          # Template configuration
├── README.md                           # This file
└── template/                           # Template files
    ├── .gitignore.template
    ├── .semgrepignore.template
    ├── .pre-commit-config.yaml.template
    ├── build.gradle.kts.template
    ├── settings.gradle.kts.template
    ├── gradle.properties.template
    ├── justfile.template
    ├── README.md.template
    ├── AGENTS.md.template
    ├── CLAUDE.md -> AGENTS.md         # Symlink (created via _tasks)
    ├── .cursor/
    │   └── commands/
    │       └── doc-statemachine.md    # Cursor AI command for state machine diagrams
    ├── gradle/
    │   └── wrapper/
    │       ├── gradle-wrapper.jar
    │       └── gradle-wrapper.properties
    ├── gradlew                        # Gradle wrapper (Unix)
    ├── gradlew.bat                    # Gradle wrapper (Windows)
    ├── src/
    │   ├── main/java/{{package_path}}/
    │   │   └── Main.java.template
    │   └── test/java/{{package_path}}/
    │       ├── MainTest.java.template
    │       └── architecture/
    │           └── ArchitectureTest.java.template
    ├── scripts/
    ├── data/
    │   ├── input/
    │   └── output/
    └── config/
        ├── checkstyle/
        │   └── checkstyle.xml
        ├── semgrep/
        │   ├── no-default-values.yml
        │   ├── no-sneaky-fallbacks.yml
        │   └── no-suppression.yml
        └── codespell/
            └── ignore.txt
```

## Usage

### Via just create

```bash
cd /path/to/ai-guardrails
just create java-cli-base my-java-project
```

### Direct Copier usage

```bash
copier copy blueprints/java-cli-base my-java-project
cd my-java-project
just init
just run
```

## Template Questions

The template will ask:

- **project_name**: Project name (e.g., my-cli-tool)
- **group_id**: Maven group ID (e.g., com.example)
- **package_name**: Java package name (e.g., com.example.myapp)
- **project_description**: Short description
- **java_version**: Java version (21 or 23)
- **author_name**: Author name
- **author_email**: Author email
- **coverage_threshold**: Code coverage threshold (0-100, default 80)

## Generated Project Features

Projects created from this template include:

- **Strict Java execution**: Only via Gradle wrapper (`./gradlew`), never system Gradle
- **Complete validation suite**: All tools configured in build.gradle.kts, plus Infer static analysis (null safety, resource leaks)
- **Just recipes**: init, run, destroy, code-*, test, ci, ci-quiet
- **Pre-commit hooks**: Runs `just ci-quiet` on commit
- **AI agent rules**: AGENTS.md with strict development guidelines
- **Git commit rules**: No AI attribution, explicit file staging
- **Semgrep rules**: Enforce explicit configuration, no defaults, no suppression
- **Directory structure**: src/main/java/, src/test/java/, scripts/, data/

## Semgrep Rules

| Rule | Purpose |
|------|---------|
| `no-default-values` | Bans `Optional.orElse()` / `Optional.orElseGet()` -- handle missing data explicitly |
| `no-sneaky-fallbacks` | Bans `Objects.requireNonNullElse()`, `Map.getOrDefault()`, ternary null fallbacks -- no silent defaults |
| `no-suppression` | Bans `@SuppressWarnings`, `//noinspection`, `NOSONAR` -- fix issues instead of suppressing |

## Requirements

- **Java 21+** (JDK) - [Adoptium](https://adoptium.net/)
- **just** - Command runner ([installation guide](https://github.com/casey/just#installation))
- **copier** - Template engine ([installation guide](https://copier.readthedocs.io/))
- **git** - Version control
- **codespell** - Spell checker (`brew install codespell`)
- **semgrep** - Static analysis (`brew install semgrep`)

## Testing the Template

To verify the template generates correctly:

```bash
cd /path/to/ai-guardrails
just test-java
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
cd my-java-project/main
copier update
```

## Development

To modify this template:

1. Edit files in `template/` directory
2. Test with: `just test-java` (from repository root)
3. Verify generated project works
4. Commit changes

## Sources

Based on:
- [Google Java Style Guide](https://google.github.io/styleguide/javaguide.html)
- ai-guardrails/blueprints/python-cli-base
