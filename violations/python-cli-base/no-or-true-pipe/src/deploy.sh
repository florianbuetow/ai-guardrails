#!/bin/bash
set -euo pipefail

echo "Deploying application..."
make build || true
echo "Done"
