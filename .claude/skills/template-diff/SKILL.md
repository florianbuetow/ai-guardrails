---
name: template-diff
description: Compare a specific justfile recipe or pattern across all 6 language templates to find inconsistencies
---

# Template Sync Checker

Compare a specific justfile recipe (or any pattern) across all 6 language blueprint templates to find inconsistencies, missing implementations, or drift.

## Usage

The user provides a recipe name (e.g., `code-deptry`, `ci`, `code-semgrep`) or a pattern to search for.

## Workflow

1. **Extract the target recipe** from each of the 6 justfile templates:
   - `blueprints/python-cli-base/template/justfile.template`
   - `blueprints/java-cli-base/template/justfile.template`
   - `blueprints/go-cli-base/template/justfile.template`
   - `blueprints/elixir-otp-base/template/justfile.template`
   - `blueprints/cpp-cli-base/template/justfile.template`
   - `blueprints/rust-cli-base/template/justfile.template`

2. **Compare structural patterns** across all 6:
   - Does the recipe exist in all templates?
   - Does it use `set -e` consistently (for `#!/usr/bin/env bash` recipes)?
   - Does it have proper success/failure messages following the justfile rules?
   - Does it follow the conventions in the justfile header comments (colors, echo spacing, fail-fast)?

3. **Report findings** as a table:

   | Pattern | Python | Java | Go | Elixir | C++ | Rust |
   |---------|--------|------|----|--------|-----|------|
   | Recipe exists | ... | ... | ... | ... | ... | ... |
   | Uses set -e | ... | ... | ... | ... | ... | ... |
   | Has success msg | ... | ... | ... | ... | ... | ... |
   | Has failure msg | ... | ... | ... | ... | ... | ... |

4. **Flag specific inconsistencies** with file paths and line numbers.

## Key conventions to check (from justfile header)

- `printf` for colors, not `echo`
- Empty `@echo ""` before and after each target's command block
- Composite targets must fail fast (`set -e` or `&&` chaining)
- Every target ends with green success or red failure message
- Bash recipes should have `#!/usr/bin/env bash` and `set -e`

## If searching for a pattern (not a recipe name)

Use Grep across all 6 templates and present results side by side.
