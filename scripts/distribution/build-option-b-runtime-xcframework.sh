#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'HELP'
Usage:
  scripts/build-option-b-runtime-xcframework.sh --output DIR [--configuration Release]

Requires Xcode and XcodeGen. Builds a static AutoLogRuntime.xcframework for iOS,
iOS Simulator, macOS, watchOS, and watchOS Simulator with Swift module interfaces.
Macro declarations are excluded. The output directory must be empty.
HELP
}

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_PACKAGE_DIR="$(cd "$TOOL_DIR/../.." && pwd)"
ROOT_DIR="${AUTOLOG_DISTRIBUTION_WORKSPACE:-$SOURCE_PACKAGE_DIR}"
OUTPUT_DIR=""
CONFIGURATION="Release"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output) OUTPUT_DIR="${2:?Missing output directory}"; shift 2 ;;
    --configuration) CONFIGURATION="${2:?Missing configuration}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done
[[ -n "$OUTPUT_DIR" ]] || { usage >&2; exit 2; }
command -v xcodegen >/dev/null || { echo "Install XcodeGen before building the release runtime." >&2; exit 1; }
xcodebuild -version >/dev/null
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
[[ -z "$(ls -A "$OUTPUT_DIR")" ]] || { echo "Output directory must be empty: $OUTPUT_DIR" >&2; exit 1; }

BUILD_ROOT="$ROOT_DIR/.build/option-b-runtime-xcframework"
PROJECT_DIR="$BUILD_ROOT/AutoLogRuntimeProject"
ARCHIVE_DIR="$BUILD_ROOT/archives"
rm -rf "$BUILD_ROOT"
mkdir -p "$PROJECT_DIR/Sources" "$ARCHIVE_DIR"
while IFS= read -r source_file; do
  relative_path="${source_file#"$SOURCE_PACKAGE_DIR/Sources/AutoLog/"}"
  mkdir -p "$PROJECT_DIR/Sources/$(dirname "$relative_path")"
  cp "$source_file" "$PROJECT_DIR/Sources/$relative_path"
done < <(find "$SOURCE_PACKAGE_DIR/Sources/AutoLog" -type f -name '*.swift' ! -name 'Macros.swift' | sort)

cat > "$PROJECT_DIR/project.yml" <<'SPEC'
name: AutoLogRuntime
options:
  bundleIdPrefix: com.anciltech
settings:
  base:
    SWIFT_VERSION: '6.0'
    IPHONEOS_DEPLOYMENT_TARGET: '17.0'
    MACOSX_DEPLOYMENT_TARGET: '15.0'
    WATCHOS_DEPLOYMENT_TARGET: '11.0'
    SUPPORTED_PLATFORMS: 'iphoneos iphonesimulator macosx watchos watchsimulator'
    SUPPORTS_MACCATALYST: NO
    CODE_SIGNING_ALLOWED: NO
    BUILD_LIBRARY_FOR_DISTRIBUTION: YES
    SKIP_INSTALL: NO
    DEBUG_INFORMATION_FORMAT: dwarf
    GCC_GENERATE_DEBUGGING_SYMBOLS: NO
    SWIFT_SERIALIZE_DEBUGGING_OPTIONS: NO
    SWIFT_EMIT_LOC_STRINGS: NO
    COPY_PHASE_STRIP: YES
    STRIP_INSTALLED_PRODUCT: YES
targets:
  AutoLogRuntime:
    type: framework
    platform: iOS
    sources: [Sources]
    settings:
      MACH_O_TYPE: staticlib
      PRODUCT_BUNDLE_IDENTIFIER: com.anciltech.AutoLogRuntime
      GENERATE_INFOPLIST_FILE: YES
      SUPPORTED_PLATFORMS: 'iphoneos iphonesimulator macosx watchos watchsimulator'
schemes:
  AutoLogRuntime:
    build:
      targets:
        AutoLogRuntime: all
SPEC
xcodegen generate --spec "$PROJECT_DIR/project.yml" --project "$PROJECT_DIR" >/dev/null
frameworks=()
archive_framework() {
  local name="$1" destination="$2" sdk="$3"
  local archive_path="$ARCHIVE_DIR/$name.xcarchive"
  echo "Archiving AutoLogRuntime for $name"
  if ! xcodebuild archive \
    -project "$PROJECT_DIR/AutoLogRuntime.xcodeproj" \
    -scheme AutoLogRuntime -destination "$destination" -sdk "$sdk" \
    -archivePath "$archive_path" -configuration "$CONFIGURATION" \
    -derivedDataPath "$BUILD_ROOT/DerivedData" \
    SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES CODE_SIGNING_ALLOWED=NO \
    > "$ARCHIVE_DIR/$name.log" 2>&1; then
    tail -80 "$ARCHIVE_DIR/$name.log" >&2
    return 1
  fi
  local framework="$archive_path/Products/Library/Frameworks/AutoLogRuntime.framework"
  [[ -d "$framework/Modules/AutoLogRuntime.swiftmodule" ]] || { echo "Missing framework modules: $framework" >&2; return 1; }
  frameworks+=("-framework" "$framework")
}
archive_framework ios 'generic/platform=iOS' iphoneos
archive_framework ios-simulator 'generic/platform=iOS Simulator' iphonesimulator
archive_framework macos 'generic/platform=macOS' macosx
archive_framework watchos 'generic/platform=watchOS' watchos
archive_framework watchos-simulator 'generic/platform=watchOS Simulator' watchsimulator
xcodebuild -create-xcframework "${frameworks[@]}" \
  -output "$OUTPUT_DIR/AutoLogRuntime.xcframework" > "$OUTPUT_DIR/create-xcframework.log" 2>&1
(
  cd "$OUTPUT_DIR"
  /usr/bin/zip -qry AutoLogRuntime.xcframework.zip AutoLogRuntime.xcframework
  swift package compute-checksum AutoLogRuntime.xcframework.zip > AutoLogRuntime.xcframework.zip.checksum
)
echo "Built $OUTPUT_DIR/AutoLogRuntime.xcframework"
echo "Checksum: $(cat "$OUTPUT_DIR/AutoLogRuntime.xcframework.zip.checksum")"
