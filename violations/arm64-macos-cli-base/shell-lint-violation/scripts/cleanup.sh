#!/usr/bin/env bash
#
# Unquoted expansion in a destructive command.

set -euo pipefail

workspace=$1
rm -rf $workspace/build
