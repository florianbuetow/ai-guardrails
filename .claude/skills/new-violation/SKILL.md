---
name: new-violation
description: Scaffold a new violation test case for a given language and rule name
---

# New Violation Test Scaffolder

Create the directory structure and files for a new violation test case.

## Arguments

- **language**: One of `python`, `java`, `go`, `elixir`, `cpp`, `rust`
- **violation-name**: Kebab-case name (e.g., `no-default-values`, `security-hardcoded-password`)
- **check-recipe** (optional): The justfile recipe to run. Defaults to `code-semgrep`.

Ask the user for these if not provided.

## Workflow

1. **Validate** the language is one of the 6 supported languages.

2. **Check for duplicates**: Verify `violations/<language>/<violation-name>/` does not already exist.

3. **Determine the check recipe**:
   - If the user specifies one, use it.
   - If the violation name starts with a known prefix, suggest the matching recipe:

     | Prefix / Pattern | Recipe |
     |------------------|--------|
     | `no-*`, `python-constants` | `code-semgrep` (default) |
     | `style-*` | `code-style` |
     | `typecheck-*` | `code-typecheck` |
     | `lsp-*` | `code-lspchecks` |
     | `security-*` | `code-security` |
     | `spell-*` | `code-spell` |
     | `deptry-*` | `code-deptry` |
     | `audit-*` | `code-audit` |
     | `arch-*` | `code-architecture` |
     | `lint-*` | `code-lint` or `lint` |
     | `sanitize-*` | `code-sanitize` |

   - If the recipe is `code-semgrep` (the default), no `check` file is needed.
   - Otherwise, create a `check` file containing just the recipe name.

4. **Create the directory**: `violations/<language>/<violation-name>/`

5. **Create the `check` file** (only if recipe is not `code-semgrep`):
   Write the recipe name to `violations/<language>/<violation-name>/check` with no trailing newline.

6. **Create the violation file(s)**:
   - Look at existing violations for the same language to understand the file structure.
   - The violation files must overlay onto a generated project, so paths must match the template's project structure.
   - Common overlay locations by language:

     | Language | Typical overlay paths |
     |----------|----------------------|
     | Python | `src/main.py`, `tests/test_main.py`, `pyproject.toml` |
     | Java | `src/main/java/.../App.java`, `build.gradle.kts` |
     | Go | `cmd/main.go`, `internal/app/app.go`, `go.mod` |
     | Elixir | `lib/<app>.ex`, `test/<app>_test.exs`, `mix.exs` |
     | C++ | `src/app.cpp`, `include/<project>/app.hpp`, `tests/app_test.cpp` |
     | Rust | `src/main.rs`, `src/lib.rs`, `Cargo.toml` |

   - Ask the user what the violation code should look like, or generate it if the rule is clear from the name.

7. **Verify the violation file is valid code** that would compile/parse — the only issue should be the guardrail violation itself.

8. **Remind the user** to run `just test-<language>` to verify the violation is detected.

## Important rules

- Violation files must contain valid, compilable code — the only "bad" thing is the guardrail pattern.
- Never use placeholder or broken syntax.
- If the violation requires a new semgrep rule, tell the user it needs to be created in `blueprints/<language>-*/template/config/semgrep/` first.
