#!/bin/sh
set -eu

os=$(uname -s)
case "$os" in
  Darwin)
    required_commands='git just sh bash dash ksh zsh shfmt shellcheck checkbashisms semgrep codespell bats shellspec kcov'
    install_hint='brew install bash dash ksh zsh shfmt shellcheck checkbashisms bats-core shellspec kcov semgrep codespell just'
    ;;
  Linux)
    required_commands='git just sh bash dash busybox ksh zsh shfmt shellcheck checkbashisms semgrep codespell bats shellspec kcov'
    install_hint='Install the listed tools with your distribution package manager; see README.md for package names and upstream installation links.'
    ;;
  *)
    printf '\033[31m✗ Unsupported operating system: %s\033[0m\n' "$os" >&2
    printf '  This template supports macOS and Linux.\n' >&2
    exit 1
    ;;
esac

for command_name in $required_commands; do
  if ! command -v "$command_name" > /dev/null 2>&1; then
    printf '\033[31m✗ Required command is not installed: %s\033[0m\n' "$command_name" >&2
    printf '  %s\n' "$install_hint" >&2
    exit 1
  fi
done

bash_major=$(bash --version | sed -n '1s/.*version \([0-9][0-9]*\).*/\1/p')
case "$bash_major" in
  '' | *[!0-9]*)
    printf '\033[31m✗ Could not determine the Bash version\033[0m\n' >&2
    exit 1
    ;;
esac
if [ "$bash_major" -lt 4 ]; then
  printf '\033[31m✗ Bash 4 or newer is required for coverage; found Bash %s\033[0m\n' "$bash_major" >&2
  printf '  macOS: brew install bash and place the Homebrew bin directory before /bin in PATH.\n' >&2
  exit 1
fi

if [ "$os" = Linux ] && ! busybox ash -c ':'; then
  printf '\033[31m✗ BusyBox ash is not usable\033[0m\n' >&2
  exit 1
fi

printf '\033[32m✓ All required commands are installed\033[0m\n'
