# TypeScript React Base Template

Copier blueprint for a React + Vite + TypeScript application with the full
ai-guardrails validation suite.

Generation runs in two phases inside a single `copier copy`:

1. **Copy phase** — provisions the guardrail layer (justfile, semgrep rules,
   ESLint/Prettier/Vitest/Playwright/dependency-cruiser/knip configs, AGENTS.md).
2. **Task phase** — runs `npm create vite@latest -- --template react-ts` into a
   temp subdir, merges the scaffold into the project root (template files always
   win), and installs the guardrail toolchain unpinned. Nothing is frozen: every
   apply gets the current Vite scaffold and current tool versions.

Requires network access at generation time.

Usage:

    just create typescript-react-base <target-dir>

Validation: prettier, eslint (typescript-eslint strict-type-checked, react-hooks,
jsx-a11y), tsc, semgrep, codespell, eslint security pass (security + no-unsanitized),
knip, dependency-cruiser, vitest (+coverage), Playwright e2e, npm audit.
