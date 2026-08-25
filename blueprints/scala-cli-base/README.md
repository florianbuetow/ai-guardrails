# Scala CLI Base Template

Production-ready Copier template for Scala 3 CLI applications with executable architectural, semantic, compiler, security, dependency, testing, and coverage guardrails.

## Validation stack

| Tool | Enforced purpose |
| --- | --- |
| Scalafmt | Scala and sbt formatting |
| Scalafix | Built-in source policy plus a tested project-local semantic rule |
| scalac | Warnings-as-errors, unused code, discarded values, and safe initialization |
| WartRemover | Unsafe and partial Scala constructs |
| Find Security Bugs | JVM bytecode security analysis |
| Semgrep | Repository-specific forbidden patterns |
| sbt-explicit-dependencies | Unused and undeclared compile dependencies |
| sbt-dependency-lock | Reproducible dependency graph consumed by Trivy |
| Trivy | HIGH/CRITICAL dependency vulnerabilities |
| sbt-updates | Available dependency updates |
| MUnit | Application unit tests |
| ArchUnit | Package dependencies and cycle rules |
| scoverage | Statement and branch coverage thresholds |

The generated project includes a verified sbt launcher, so only JDK 21 and the external command-line checkers are required.

## Usage

```bash
just create scala-cli-base my-scala-project
cd my-scala-project
just init
just ci
just run
```

## Template verification

```bash
just test-scala
```

The Scala suite generates a clean project, runs every tool through `just ci`, runs the application, fires the generated pre-commit hook, and injects each violation to prove the corresponding check fails.
