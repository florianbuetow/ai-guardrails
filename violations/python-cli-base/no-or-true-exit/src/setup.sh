#!/bin/bash
set -euo pipefail

echo "Setting up environment..."
install_deps || exit 0
echo "Done"
