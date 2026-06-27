# React Vite TypeScript Base Template

Production-ready Copier template for React + Vite + TypeScript applications with full validation infrastructure.

## Features

- **React + Vite + TypeScript** scaffolded fresh from `npm create vite` at apply time — nothing frozen
- **Two-phase generation**: Copier provisions the guardrail layer, then a post-task merges the current Vite scaffold into the project root and installs the toolchain unpinned
- **Just task runner** for all commands (npm/npx underneath)
- **Pre-commit hooks** with CI checks
- **Comprehensive AGENTS.md** for AI-assisted development

Requires network access at generation time (`npm create vite` + `npm install`).

### Validation Tools

| Tool | Purpose | Why It's Used |
|------|---------|---------------|
| **prettier** | Formatting | One consistent style; `code-format` writes, `code-style` checks |
| **Oxlint** | Linting | react-hooks + jsx-a11y + correctness rules; zero warnings allowed |
| **tsc** | Type checks | Strict compiler pass over app, node, and e2e configs (`code-lspchecks`) |
| **semgrep** | Custom static analysis | Pattern-based scanning — enforces project-specific rules |
| **Oxlint security pass** | Security lint | oxlint no-eval + correctness with `--deny-warnings` (`code-security`) |
| **knip** | Dependency hygiene | Detects unused/unlisted dependencies, exports, and files (`code-deptry`) |
| **dependency-cruiser** | Architecture constraints | No cycles, no orphans, no src→test imports (`code-architecture`) |
| **codespell** | Spell checking | Catches typos in code, comments, and documentation |
| **Vitest + Testing Library** | Testing and coverage | Component tests in jsdom with v8 coverage thresholds |
| **Playwright** | End-to-end testing | Browser test against the production build via `vite preview` |
| **npm audit + npm-check-updates** | Dependency audit | Fails on HIGH vulnerabilities; reports outdated packages (`code-audit`) |

## Template Structure

```
blueprints/react-vite-typescript-base/
├── copier.yml                          # Template configuration
├── README.md                           # This file
└── template/                           # Template files
    ├── .gitignore.template
    ├── .semgrepignore.template
    ├── .pre-commit-config.yaml.template
    ├── justfile.template
    ├── README.md.template
    ├── AGENTS.md.template
    ├── .oxlintrc.json                  # Hardened oxlint config (replaces scaffold's)
    ├── .prettierrc / .prettierignore
    ├── vitest.config.ts.template
    ├── playwright.config.ts
    ├── tsconfig.e2e.json
    ├── .dependency-cruiser.cjs
    ├── knip.json
    ├── scripts/
    │   └── bootstrap-vite.sh.template  # Phase 2: scaffold + merge + toolchain install
    ├── src/
    │   ├── App.tsx                     # Lint-clean version of the scaffold component
    │   ├── main.tsx                    # Fail-fast entry point (explicit root check)
    │   ├── App.test.tsx
    │   └── test-setup.ts
    ├── e2e/
    │   └── app.spec.ts
    ├── data/
    │   ├── input/
    │   └── output/
    └── config/
        ├── oxlint/
        │   └── security.oxlintrc.json
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

Everything else (`package.json`, `vite.config.ts`, `tsconfig*.json`, `index.html`, `public/`, asset files) comes from the live Vite scaffold at apply time. The merge rule is simple: template files always win; the scaffold fills in the rest. The bootstrap installs oxlint plus the rest of the toolchain at current versions; the Vite scaffold already lints with oxlint, so no ESLint stack is needed.

## Usage

### Via just create

```bash
cd /path/to/ai-guardrails
just create react-vite-typescript-base my-react-app
```

### Direct Copier usage

```bash
copier copy --trust blueprints/react-vite-typescript-base my-react-app
cd my-react-app
just init
just run
```

## Template Questions

The template will ask:

- **project_name**: npm package name (lowercase, e.g. my-react-app)
- **project_description**: Short description
- **node_version**: Minimum Node.js major version (22 or 24)
- **author_name**: Author name
- **author_email**: Author email
- **coverage_threshold**: Code coverage threshold (0-100, default 80)

## Generated Project Features

Projects created from this template include:

- **npm-only tooling**: All JS tooling via `npm`/`npx` — never yarn, pnpm, or bun
- **Complete validation suite**: prettier, oxlint, tsc, semgrep, security pass, knip, dependency-cruiser, Vitest, Playwright, npm audit — all wired into `just ci`
- **Just recipes**: init, run, build, destroy, code-*, test, test-coverage, test-e2e, ci, ci-quiet
- **Pre-commit hooks**: Runs `just ci-quiet` on commit
- **AI agent rules**: AGENTS.md with strict development guidelines
- **Git commit rules**: No AI attribution, explicit file staging
- **Fail-fast entry point**: `main.tsx` throws if the root element is missing instead of using a `!` assertion
- **Directory structure**: src/, e2e/, scripts/, data/, config/

## Semgrep Rules

| Rule | Purpose |
|------|---------|
| `no-default-values` | Bans `import.meta.env.X ?? default` / `process.env.X \|\| default` — fail explicitly on missing configuration |
| `no-sneaky-fallbacks` | Bans empty `catch {}` blocks — handle failures or let them propagate |
| `no-skip-tests` | Bans `.skip` / `.only` / `xit` / `xdescribe` / `xtest` — tests must pass or fail |
| `no-suppression` | Bans `eslint-disable`, `oxlint-disable`, `@ts-ignore`, `@ts-expect-error`, `@ts-nocheck`, `prettier-ignore`, coverage-ignore comments |
| `no-shellcheck-disable` | Bans `# shellcheck disable=` in shell scripts |
| `security-predictable-random` | Bans `Math.random()` — use `crypto.getRandomValues()` for security-sensitive values |

## Requirements

- **Node.js 22+** and npm - [nodejs.org](https://nodejs.org/)
- **just** - Command runner ([installation guide](https://github.com/casey/just#installation))
- **copier** - Template engine ([installation guide](https://copier.readthedocs.io/))
- **git** - Version control
- **codespell** - Spell checker (`brew install codespell`)
- **semgrep** - Static analysis (`brew install semgrep`)

## Testing the Template

To verify the template generates correctly:

```bash
cd /path/to/ai-guardrails
just test-typescript
```

This will:
1. Generate a test project in a temp directory (runs the live `npm create vite` bootstrap)
2. Run `just ci` on the clean project (baseline must pass)
3. Inject each violation and verify the project's own guardrails catch it
4. Clean up the temp directory

## Sources

Based on:
- ai-guardrails/blueprints/kotlin-cli-base (conventions) and the [Vite](https://vite.dev/) react-ts scaffold
- [oxlint](https://oxc.rs/docs/guide/usage/linter.html), [Vitest](https://vitest.dev/), [Playwright](https://playwright.dev/), [knip](https://knip.dev/), [dependency-cruiser](https://github.com/sverweij/dependency-cruiser)
