# Kotlin CLI Base Template

Production-ready Copier template for Kotlin CLI applications with full validation infrastructure.

## Features

- **Kotlin 2.1+ on the JVM** with Gradle Kotlin DSL build system
- **Gradle Wrapper** included for reproducible builds
- **Just task runner** for all commands
- **Pre-commit hooks** with CI checks
- **Comprehensive AGENTS.md** for AI-assisted development

### Validation Tools

| Tool | Purpose | Why It's Used |
|------|---------|---------------|
| **ktlint** | Formatting & style | Enforces a consistent Kotlin style, including no wildcard imports |
| **detekt** | Static analysis | Catches bug patterns, risky exception handling, and excess complexity |
| **kotlinc allWarningsAsErrors** | LSP-equivalent checks | Every compiler warning is a build error (unused symbols, deprecation, etc.) |
| **semgrep** | Custom static analysis | Pattern-based scanning — enforces project-specific rules |
| **Dependency Analysis** | Dependency hygiene | Detects unused and undeclared dependencies |
| **codespell** | Spell checking | Catches typos in code, comments, and documentation |
| **trivy** | Vulnerability scanning | Flags HIGH/CRITICAL CVEs in resolved dependencies |
| **Gradle Versions Plugin** | Dependency version audit | Detects outdated dependencies with available updates |
| **Konsist** | Architecture constraints | Enforces package/import rules — prevents architectural erosion |
| **JUnit 5 + Kover** | Testing and coverage | Unit testing with coverage thresholds |

## Template Structure

```
blueprints/kotlin-cli-base/
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
    ├── gradle/
    │   └── wrapper/
    │       ├── gradle-wrapper.jar
    │       └── gradle-wrapper.properties
    ├── gradlew                        # Gradle wrapper (Unix)
    ├── gradlew.bat                    # Gradle wrapper (Windows)
    ├── src/
    │   ├── main/kotlin/{{package_path}}/
    │   │   └── Main.kt.template
    │   └── test/kotlin/{{package_path}}/
    │       ├── MainTest.kt.template
    │       └── architecture/
    │           └── ArchitectureTest.kt.template
    ├── scripts/
    ├── data/
    │   ├── input/
    │   └── output/
    └── config/
        ├── detekt/
        │   └── detekt.yml
        ├── semgrep/
        │   ├── no-default-values.yml
        │   ├── no-sneaky-fallbacks.yml
        │   ├── no-skip-tests.yml
        │   ├── no-suppression.yml
        │   ├── no-shellcheck-disable.yml
        │   └── security-predictable-random.yml
        └── codespell/
            └── ignore.txt
```

## Usage

### Via just create

```bash
cd /path/to/ai-guardrails
just create kotlin-cli-base my-kotlin-project
```

### Direct Copier usage

```bash
copier copy blueprints/kotlin-cli-base my-kotlin-project
cd my-kotlin-project
just init
just run
```

## Template Questions

The template will ask:

- **project_name**: Project name (e.g., my-cli-tool)
- **group_id**: Maven/Gradle group ID (e.g., com.example)
- **package_name**: Kotlin package name (e.g., com.example.myapp)
- **project_description**: Short description
- **jvm_target**: JVM toolchain version (21 or 23)
- **author_name**: Author name
- **author_email**: Author email
- **coverage_threshold**: Code coverage threshold (0-100, default 80)

## Generated Project Features

Projects created from this template include:

- **Strict Kotlin execution**: Only via Gradle wrapper (`./gradlew`), never system Gradle
- **Complete validation suite**: ktlint, detekt, Kover, Konsist, semgrep, trivy — all wired into `just ci`
- **Just recipes**: init, run, destroy, code-*, test, ci, ci-quiet
- **Pre-commit hooks**: Runs `just ci-quiet` on commit
- **AI agent rules**: AGENTS.md with strict development guidelines
- **Git commit rules**: No AI attribution, explicit file staging
- **Semgrep rules**: Enforce explicit configuration, no defaults, no suppression
- **Directory structure**: src/main/kotlin/, src/test/kotlin/, scripts/, data/

## Semgrep Rules

| Rule | Purpose |
|------|---------|
| `no-default-values` | Bans `Map.getOrDefault()` and `System.getenv(...) ?: default` — handle missing data explicitly |
| `no-sneaky-fallbacks` | Bans `getOrElse()` / `getOrNull()` fallbacks — no silent defaults |
| `no-skip-tests` | Bans `@Disabled` / `@Ignore` / `assumeTrue` — tests must pass or fail |
| `no-suppression` | Bans `@Suppress`, `@SuppressWarnings`, `//noinspection`, `NOSONAR` — fix issues instead of suppressing |
| `no-shellcheck-disable` | Bans `# shellcheck disable=` in shell scripts |
| `security-predictable-random` | Bans `java.util.Random` — use `java.security.SecureRandom` |

## Requirements

- **JDK 21+** - [Adoptium](https://adoptium.net/)
- **just** - Command runner ([installation guide](https://github.com/casey/just#installation))
- **copier** - Template engine ([installation guide](https://copier.readthedocs.io/))
- **git** - Version control
- **codespell** - Spell checker (`brew install codespell`)
- **semgrep** - Static analysis (`brew install semgrep`)
- **trivy** - Vulnerability scanner (`brew install trivy`)

## Testing the Template

To verify the template generates correctly:

```bash
cd /path/to/ai-guardrails
just test-kotlin
```

This will:
1. Generate a test project in a temp directory
2. Run `just ci` on the clean project (baseline must pass)
3. Inject each violation and verify the project's own guardrails catch it
4. Clean up the temp directory

## Sources

Based on:
- ai-guardrails/blueprints/java-cli-base
- [detekt](https://detekt.dev/), [ktlint](https://pinterest.github.io/ktlint/), [Konsist](https://docs.konsist.lemonappdev.com/), [Kover](https://github.com/Kotlin/kotlinx-kover)
