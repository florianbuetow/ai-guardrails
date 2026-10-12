#!/bin/bash
set -euo pipefail

# shellcheck source=environment.sh
source scripts/environment.sh
for directory in .tools .tools/bin .tools/packages .tools/downloads; do
    if [ -L "$directory" ]; then
        printf 'Refusing symlinked tool directory: %s\n' "$directory" >&2
        exit 1
    fi
    mkdir -p "$directory"
done

while IFS=$'\t' read -r name version kind url checksum; do
    [ -n "$name" ] && [ -n "$version" ] && [ -n "$kind" ] && [ -n "$url" ] && [ -n "$checksum" ]
    case "$name/$version" in *..* | /*)
        printf 'Invalid tool identity\n' >&2
        exit 1
        ;;
    esac
    archive="$PWD/.tools/downloads/$name-$version"
    if [ ! -f "$archive" ]; then
        curl --fail --location --show-error --silent --proto '=https' --tlsv1.2 "$url" -o "$archive.part"
        mv "$archive.part" "$archive"
    fi
    printf '%s  %s\n' "$checksum" "$archive" | shasum -a 256 --check --status
    package="$PWD/.tools/packages/$name-$version"
    if [ ! -d "$package" ]; then
        staging="$(mktemp -d "$PWD/.tools/staging.XXXXXXXX")"
        trap 'rm -rf "$staging"' EXIT
        case "$kind" in
            zip) unzip -q "$archive" -d "$staging" ;;
            tar) tar -xzf "$archive" -C "$staging" ;;
            binary) install -m 755 "$archive" "$staging/$name" ;;
            *)
                printf 'Unknown archive type: %s\n' "$kind" >&2
                exit 1
                ;;
        esac
        mv "$staging" "$package"
        trap - EXIT
    fi
    executable="$(find "$package" -type f -name "$name")"
    [ -n "$executable" ] && [ "$(printf '%s\n' "$executable" | wc -l | tr -d ' ')" = 1 ]
    chmod +x "$executable"
    ln -sf "$executable" ".tools/bin/$name"
    printf 'Installed %s %s\n' "$name" "$version"
done <config/tools.lock.tsv

export UV_PYTHON_INSTALL_DIR="$PWD/.tools/python-distributions"
.tools/bin/uv python install 3.14.8
if [ ! -d .tools/python ]; then
    .tools/bin/uv venv --python 3.14.8 .tools/python
fi
[ "$(.tools/python/bin/python --version)" = 'Python 3.14.8' ]
.tools/bin/uv pip sync --python .tools/python/bin/python --require-hashes config/python-tools.lock
for name in semgrep codespell; do
    ln -sf "$PWD/.tools/python/bin/$name" ".tools/bin/$name"
done
printf '\033[32mAll pinned tools installed\033[0m\n'
