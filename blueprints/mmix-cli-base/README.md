# MMIX CLI Base

A portable MMIXAL development and verification environment. Generated projects
build their own pinned `mmixal`, `mmix`, and `mmotype` from committed C sources.
Validation requires Git, `just`, and a C compiler: GCC/Clang on macOS/Linux or
MSVC in Developer PowerShell on Windows. No validation command downloads anything.

```text
copier copy --trust blueprints/mmix-cli-base ./my-mmix-cli
cd my-mmix-cli
just init
just run 4
just ci
```

The multi-module sample separates command orchestration, parsing, formatting,
and MMIX I/O. A single local C guard provides source/hygiene policies, exact
capability allowlists, SHA-256 vendor integrity, structural object/listing
checks, declarative CLI/state tests, and real instruction coverage (80% minimum).
MMIX unit tests are independently assembled programs. Core validation is shared
by every platform; shell/PowerShell code only bootstraps the compiler and driver.

See the generated README for the command and tooling matrices, test schemas,
static-analysis limits, host prerequisites, and documented exclusions. The
application artifact is `.mmo`, not a host-native application executable.

Run `just test-mmix-cli-base` in ai-guardrails for fresh generation, clean rebuild,
complete local CI, and deliberate violation checks. Python/Copier are parent
blueprint-test dependencies only; generated projects do not use them.
