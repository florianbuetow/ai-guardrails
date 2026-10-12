#!/usr/bin/env bash
set -euo pipefail
case "$(uname -s)" in
    Darwin)
        exec just container-ci
        ;;
    Linux)
        exec just ci-quiet
        ;;
    *)
        printf 'Commit validation requires macOS with Docker or ARM64 Linux.\n' >&2
        exit 1
        ;;
esac
