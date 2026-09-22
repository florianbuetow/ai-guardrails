# Validation status

This report records local validation of the supplied MMIX CLI specification.
No remote workflow execution was performed for this revision.

## Verified on macOS

- Fresh Copier generation, saved answers, correct CLAUDE.md symbolic link, Git setup,
  local pre-commit hook, host-tool build, and sample execution.
- MMIX parsing/formatting unit programs, declarative CLI tests, and simulator state
  assertions for local/global/special registers, memory, PC, and termination.
- All 21 committed violation cases reject their declared stage.
- Real executable-instruction coverage: 46/46 instructions, 100%; configured floor 80%.
- Delete-build reconstruction plus build, test, coverage, ci, and ci-quiet inside an
  OS sandbox that denies networking.
- The complete C-driven CI pipeline with AddressSanitizer and UndefinedBehaviorSanitizer.
- Strict C11 warnings-as-errors compilation and Clang static analysis without findings.
- Repository prerequisite, inventory, content-tracking, spelling, and shell checks.
  Content tracking used a disposable Git index; the actual index was not changed.
- Local repository Semgrep rules passed; Semgrep is not a generated-project dependency.

## Verified on Linux

A one-off Debian Linux ARM64 Docker environment passed the complete lifecycle and
all 21 violation cases with both GCC 14.2 and Clang 19.1. Validation ran with
container networking disabled and the repository mounted read-only. The temporary
image and containers were removed; Docker is not a project validation dependency.

## Still requires execution

| Platform | Remaining verification |
| --- | --- |
| Windows | Run with MSVC cl.exe and inbox PowerShell, including native argument forwarding and symlinks. |

Both GitHub Actions matrices are configured, but were not triggered because this
revision has not been published. Earlier CI runs for the provisional implementation
do not validate this revision. The full cross-platform definition of done remains
unverified until Windows executes the new suite.

## Reproduce

From ai-guardrails, run `python3 tests/test_mmix.py` (Copier is a generation-only
prerequisite). In a generated project, run `just destroy` followed by `just ci`.
Use Visual Studio Developer PowerShell on Windows, with symlink creation available.
