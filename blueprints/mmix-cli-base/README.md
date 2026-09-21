# MMIX Assembly CLI Base Template

A self-contained Copier template for command-line programs written in MMIX assembly.

The generated project vendors pinned, generated C sources for Donald Knuth's MMIXware and builds `mmixal`, `mmix`, and `mmotype` locally. Its guardrails are repository-contained C programs and portable scripts. Validation does not use Semgrep, Gitleaks, codespell, containers, external rule packs, hosted APIs, or downloaded rule data.

## Generate a project

```bash
copier copy --trust blueprints/mmix-cli-base ./my-mmix-cli
cd ./my-mmix-cli
just init
just run
just ci
```

Run `just help` to see every recipe.

## Validation

The local pipeline validates `.mms` source policy, assembles source with `mmixal`, inspects `.mmo` structure with `mmotype`, executes black-box tests with `mmix`, checks generated artifacts, and derives instruction coverage from execution profiles. MMIXAL assembler diagnostics fail validation. The unmodified upstream C uses legacy K&R definitions and may emit compiler warnings; local C guardrails compile with warnings as errors.

## Prerequisites

- A GCC/Clang-compatible C compiler (`cc` on macOS/Linux; `clang` in Git Bash on Windows)
- `just`
- Git
- Copier, for generating the project

MMIXware itself is included in the generated repository and the validation workflow performs no network access.
