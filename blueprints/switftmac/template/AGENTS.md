# Working in this application

Read README.md and project.yml before making changes. Use `just` recipes for all
build, test, validation and launch operations. Do not edit generated Xcode project
files or files inside .tools/, build/ or Tools/Guardrails/.build/.

## Invariants

- Swift 6 mode, warnings as errors, strict concurrency and strict memory safety.
- No forced unwrap/cast/try, discarded errors, empty catches or silent defaults.
- No checker suppression, unchecked Sendable, unsafe actor-isolation bypasses,
  skipped tests, expected failures or automatic snapshot acceptance in CI.
- App imports AppUI. AppUI imports SwiftUI only. No other source modules belong in
  the starter application.
- Keep the starter interface exact: one window with centered `Hello World!` text
  and uses the standard red title-bar button to close the window.
- Every selected tool is installed and configured by `just init`. A missing tool
  or failed scanner is an error. Never turn a missing prerequisite into a skip.
- Run `just code-format` deliberately, then `just ci`. CI checks formatting without
  changing files.
- Inspect real .xcresult failures and screenshots; do not rely on the test process
  exit code alone or hide missing test execution behind a passing summary.
- Keep snapshot references reviewed and tied to the documented rendering host.
- Keep credentials in Keychain. Signing and notarization are release operations.

## Files

Sources/ contains the App and AppUI modules. Tests/ contains unit, snapshot and
view inspection tests. UITests/ exercises the running app and measures launch time.
Tools/Guardrails/ owns custom SwiftSyntax analysis. scripts/ owns CLI orchestration
and strict report validation. config/ contains pinned tool downloads and policies.
Documentation/ contains the DocC guide. .githooks/pre-commit invokes the same CI as
developers. Tests for new guardrails must include code that should pass and code
that should be rejected; compile errors do not prove a policy rule works.
