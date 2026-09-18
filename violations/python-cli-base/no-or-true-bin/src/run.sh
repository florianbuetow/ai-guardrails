#!/bin/bash
set -euo pipefail

echo "Running task..."
some_command || /bin/true
echo "Done"
