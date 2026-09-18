#!/bin/bash
set -euo pipefail

echo "Cleaning up..."
rm -rf build/ || :
echo "Done"
