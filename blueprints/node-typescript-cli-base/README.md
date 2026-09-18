# Node.js TypeScript CLI Base Template

A Copier template for command-line tools built with TypeScript on Node.js.

The generated project uses Node.js 24+, ES modules, npm, and a `cli -> application -> domain` architecture. Every guardrail runs locally from the repository — no containers, SaaS, databases, external APIs, or hosted analysis. It includes strict formatting, linting, type checking, custom Semgrep policies, dead-code and dependency hygiene, import-graph and deep architecture rules, CodeQL data-flow analysis, secret detection, unit, property-based, type-level, CLI black-box and package-artifact tests, coverage and mutation thresholds, package correctness checks, and a fail-fast CI workflow.

## Generate a project

```bash
copier copy --trust blueprints/node-typescript-cli-base ./my-cli
cd ./my-cli
just init
just test
```

Run `just run -- --help` to execute the CLI from source.
