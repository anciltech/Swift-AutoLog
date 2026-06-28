#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXTURE_DIR="$PACKAGE_DIR/fixtures/watch-tasklog-release"
BUILD_ROOT="${TMPDIR:-/tmp}/autolog-watch-tasklog-release-smoke"

rm -rf "$BUILD_ROOT"
mkdir -p "$BUILD_ROOT"

build_fixture() {
  local name="$1"
  local destination="$2"
  local derived_data="$BUILD_ROOT/$name"

  (
    cd "$FIXTURE_DIR"
    xcodebuild build \
      -scheme WatchTaskLogReleaseFixture \
      -configuration Release \
      -destination "$destination" \
      -derivedDataPath "$derived_data" \
      -skipMacroValidation \
      -skipPackagePluginValidation \
      CODE_SIGNING_ALLOWED=NO \
      CODE_SIGNING_REQUIRED=NO \
      CODE_SIGN_IDENTITY="" \
      SWIFT_TREAT_WARNINGS_AS_ERRORS=NO
  )
}

build_fixture "watchsimulator" "generic/platform=watchOS Simulator"
build_fixture "watchos" "generic/platform=watchOS"
