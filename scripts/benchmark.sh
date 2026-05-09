#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

swift test \
  --configuration release \
  --package-path "$PACKAGE_DIR" \
  --filter AutoLogPerformanceTests
