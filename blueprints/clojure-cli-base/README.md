# Clojure CLI Base Blueprint

Copier blueprint for a Clojure CLI project using Clojure CLI, `deps.edn`, and `tools.build`.

## Guardrails

- Formatting: cljfmt
- Static analysis: clj-kondo and Eastwood
- Runtime contracts: Malli
- Property and generative tests: test.check through Kaocha
- Source security: clj-holmes and Semgrep
- Dependency hygiene: unused-deps plus tools.deps/clj-kondo ownership analysis
- Dependency vulnerability scan: Trivy over the generated Maven dependency graph
- Outdated dependencies: antq
- Architecture: clj-depend
- Coverage: kaocha-cloverage

## Quick Start

```bash
copier copy blueprints/clojure-cli-base my-clojure-project
cd my-clojure-project
just init
just run
```
