# Shell Scripts Base Template

Copier blueprint for portable shell scripts on macOS and Linux, using the
repository's Justfile workflow and baseline/violation testing conventions.

```sh
just create shellscripts-base /tmp/my-shell-project
cd /tmp/my-shell-project
just init
just run
just ci
```

The generated project includes `src/`, `scripts/`, `test/`, `spec/`, `config/`,
`data/`, agent guidance, and a pre-commit hook running `just ci-quiet`.
The initial CLI takes a required name and demonstrates input validation.

Both CI modes run shfmt, ShellCheck, native shell parsers, checkbashisms,
Semgrep, codespell, executable `test/test*.sh` tests, an interpreter matrix,
Bats, ShellSpec, and Kcov coverage. Plain tests fail whenever any script returns
nonzero. `init` makes scripts executable, including shebang-identified files
without extensions. Scripts use POSIX `sh` by default.

macOS checks sh, Bash, dash, ksh, and zsh; Linux also checks BusyBox ash.
The macOS toolchain is available through Homebrew. Coverage requires Bash 4+
and Kcov 38+; put Homebrew Bash first in `PATH` on macOS. Full setup instructions
and tool references are in the [generated README](template/README.md.template).

Run `just test-shellscripts-base` for the generated baseline, pre-commit hook, and
injected violation checks, or `just baseline-shellscripts-base` for baseline only.
The [Linux CI image](docker/Dockerfile.linux-ci) provisions the Linux toolchain.
