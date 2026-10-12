#!/bin/bash
set -euo pipefail

# Every caller runs from the project root; tools never resolve from a global fallback.
export PATH="$PWD/.tools/bin:$PATH"
export UV_CACHE_DIR="$PWD/.tools/uv-cache"
export CLANG_MODULE_CACHE_PATH="$PWD/build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/build/module-cache"
export SSL_CERT_FILE=/etc/ssl/cert.pem
export SEMGREP_SEND_METRICS=off
export SEMGREP_ENABLE_VERSION_CHECK=0
export SEMGREP_LOG_FILE="$PWD/build/logs/semgrep.log"
export SEMGREP_SETTINGS_FILE="$PWD/.tools/semgrep-settings.yml"
mkdir -p build/results build/logs build/reports build/module-cache
