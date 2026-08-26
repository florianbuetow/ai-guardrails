# Clojure CLI Base Blueprint

Copier blueprint for a Clojure CLI project using Clojure CLI, `deps.edn`, and `tools.build`.

## Guardrails

- Formatting: cljfmt
- Static analysis: clj-kondo and Eastwood
- Project-aware analysis: clojure-lsp built-ins plus a tested custom-linter API
- Runtime contracts: Malli
- Property and generative tests: test.check through Kaocha
- Source security: clj-holmes and Semgrep
- Dependency hygiene: unused-deps plus tools.deps/clj-kondo ownership analysis
- Dependency vulnerability scan: Trivy over the generated Maven dependency graph
- Outdated dependencies: antq
- Architecture: clj-depend
- Coverage: kaocha-cloverage

The generated project runs clojure-lsp headlessly in CI. Its checked-in configuration rejects unused public vars, inconsistent namespace aliases, cyclic namespace dependencies, and public production vars without test references. Custom linters live under `resources/clojure-lsp.exports/linters/` and are tested with the clojure-lsp test helper.

## Quick Start

```bash
copier copy blueprints/clojure-cli-base my-clojure-project
cd my-clojure-project
just init
just run
```
