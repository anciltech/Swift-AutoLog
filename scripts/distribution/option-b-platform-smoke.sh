#!/usr/bin/env bash
set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_PACKAGE_DIR="$(cd "$TOOL_DIR/../.." && pwd)"
ROOT_DIR="${AUTOLOG_DISTRIBUTION_WORKSPACE:-$SOURCE_PACKAGE_DIR}"
CONSUMER_DIR="$ROOT_DIR/.build/option-b-consumer"
BUILD_ROOT="$ROOT_DIR/.build/option-b-platform-smoke"
[[ -f "$CONSUMER_DIR/Package.swift" ]] || {
  echo "Run option-b-distribution-smoke.sh to prepare a consumer first." >&2
  exit 1
}
mkdir -p "$BUILD_ROOT"

build_consumer() {
  local name="$1" destination="$2"
  echo "Linking protected-runtime consumer for $name"
  if ! (cd "$CONSUMER_DIR" && xcodebuild build \
    -scheme OptionBConsumer -configuration Release \
    -destination "$destination" -derivedDataPath "$BUILD_ROOT/DerivedData" \
    -skipMacroValidation -skipPackagePluginValidation \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
    > "$BUILD_ROOT/$name.log" 2>&1); then
    tail -80 "$BUILD_ROOT/$name.log" >&2
    return 1
  fi
}
build_consumer ios 'generic/platform=iOS'
build_consumer ios-simulator 'generic/platform=iOS Simulator'
build_consumer watchos 'generic/platform=watchOS'
build_consumer watchos-simulator 'generic/platform=watchOS Simulator'
echo "Protected-runtime platform smoke passed"
