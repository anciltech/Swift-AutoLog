#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/prepare-option-b-distribution.sh --output DIR --runtime-binary-path PATH
  scripts/prepare-option-b-distribution.sh --output DIR --runtime-binary-url URL --checksum CHECKSUM
  scripts/prepare-option-b-distribution.sh --output DIR --runtime-source-for-smoke

Optional: --version VERSION (default 0.10.3).

Creates the Option B customer package:
- public AutoLog shim target with macro declarations
- public AutoLogMacro source target
- protected AutoLogCore target supplied as a binary target

The --runtime-source-for-smoke mode copies runtime source as AutoLogCore so
the package shape can be compiled locally. Do not ship that mode to customers.
EOF
}

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_PACKAGE_DIR="$(cd "$TOOL_DIR/../.." && pwd)"
ROOT_DIR="${AUTOLOG_DISTRIBUTION_WORKSPACE:-$SOURCE_PACKAGE_DIR}"
OUTPUT_DIR=""
RUNTIME_BINARY_PATH=""
RUNTIME_BINARY_URL=""
RUNTIME_CHECKSUM=""
RUNTIME_SOURCE_FOR_SMOKE=false
VERSION="0.10.3"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="${2:?Missing release version}"
      shift 2
      ;;
    --output)
      OUTPUT_DIR="${2:-}"
      shift 2
      ;;
    --runtime-binary-path)
      RUNTIME_BINARY_PATH="${2:-}"
      shift 2
      ;;
    --runtime-binary-url)
      RUNTIME_BINARY_URL="${2:-}"
      shift 2
      ;;
    --checksum)
      RUNTIME_CHECKSUM="${2:-}"
      shift 2
      ;;
    --runtime-source-for-smoke)
      RUNTIME_SOURCE_FOR_SMOKE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Expected a semantic version." >&2; exit 2; }

if [[ -z "$OUTPUT_DIR" ]]; then
  echo "--output is required" >&2
  usage >&2
  exit 2
fi

runtime_mode_count=0
[[ -n "$RUNTIME_BINARY_PATH" ]] && runtime_mode_count=$((runtime_mode_count + 1))
[[ -n "$RUNTIME_BINARY_URL" || -n "$RUNTIME_CHECKSUM" ]] && runtime_mode_count=$((runtime_mode_count + 1))
[[ "$RUNTIME_SOURCE_FOR_SMOKE" == true ]] && runtime_mode_count=$((runtime_mode_count + 1))

if [[ "$runtime_mode_count" -ne 1 ]]; then
  echo "Choose exactly one runtime mode: --runtime-binary-path, --runtime-binary-url + --checksum, or --runtime-source-for-smoke" >&2
  exit 2
fi

if [[ -n "$RUNTIME_BINARY_URL" && -z "$RUNTIME_CHECKSUM" ]]; then
  echo "--checksum is required with --runtime-binary-url" >&2
  exit 2
fi

if [[ -n "$RUNTIME_CHECKSUM" && -z "$RUNTIME_BINARY_URL" ]]; then
  echo "--runtime-binary-url is required with --checksum" >&2
  exit 2
fi

if [[ -n "$RUNTIME_BINARY_PATH" && ! -e "$RUNTIME_BINARY_PATH" ]]; then
  echo "--runtime-binary-path does not exist: $RUNTIME_BINARY_PATH" >&2
  exit 2
fi

if [[ -d "$OUTPUT_DIR" && -n "$(ls -A "$OUTPUT_DIR")" ]]; then
  echo "Output directory must be empty: $OUTPUT_DIR" >&2
  exit 2
fi
mkdir -p "$OUTPUT_DIR/Sources/AutoLog" "$OUTPUT_DIR/Sources"
cp -R "$SOURCE_PACKAGE_DIR/Sources/AutoLogSwiftUI" "$OUTPUT_DIR/Sources/AutoLogSwiftUI"

cp "$SOURCE_PACKAGE_DIR/LICENSE" "$OUTPUT_DIR/LICENSE"
cp -R "$SOURCE_PACKAGE_DIR/Sources/AutoLogMacro" "$OUTPUT_DIR/Sources/AutoLogMacro"

{
  echo "@_exported public import AutoLogCore"
  echo
  cat "$SOURCE_PACKAGE_DIR/Sources/AutoLog/Macros.swift"
} > "$OUTPUT_DIR/Sources/AutoLog/Macros.swift"

runtime_target_manifest=""
if [[ "$RUNTIME_SOURCE_FOR_SMOKE" == true ]]; then
  mkdir -p "$OUTPUT_DIR/Sources/AutoLogCore"
  while IFS= read -r source_file; do
    relative_path="${source_file#"$SOURCE_PACKAGE_DIR/Sources/AutoLog/"}"
    mkdir -p "$OUTPUT_DIR/Sources/AutoLogCore/$(dirname "$relative_path")"
    cp "$source_file" "$OUTPUT_DIR/Sources/AutoLogCore/$relative_path"
  done < <(find "$SOURCE_PACKAGE_DIR/Sources/AutoLog" -type f -name '*.swift' ! -name 'Macros.swift' | sort)

  runtime_target_manifest='    .target(
      name: "AutoLogCore",
      path: "Sources/AutoLogCore",
      swiftSettings: [
        .swiftLanguageMode(.v6)
      ]
    ),'
elif [[ -n "$RUNTIME_BINARY_PATH" ]]; then
  mkdir -p "$OUTPUT_DIR/Artifacts"
  cp -R "$RUNTIME_BINARY_PATH" "$OUTPUT_DIR/Artifacts/AutoLogCore.xcframework"
  runtime_target_manifest="    .binaryTarget(
      name: \"AutoLogCore\",
      path: \"Artifacts/AutoLogCore.xcframework\"
    ),"
else
  runtime_target_manifest="    .binaryTarget(
      name: \"AutoLogCore\",
      url: \"$RUNTIME_BINARY_URL\",
      checksum: \"$RUNTIME_CHECKSUM\"
    ),"
fi

cat > "$OUTPUT_DIR/Package.swift" <<EOF
// swift-tools-version: 6.2
import CompilerPluginSupport
import PackageDescription

let package = Package(
  name: "Swift-AutoLog",
  platforms: [
    .macOS(.v15),
    .iOS(.v17),
    .watchOS(.v11),
  ],
  products: [
    .library(
      name: "AutoLog",
      targets: ["AutoLog"]
    ),
    .library(
      name: "AutoLogSwiftUI",
      targets: ["AutoLogSwiftUI"]
    ),
  ],
  dependencies: [
    .package(
      url: "https://github.com/swiftlang/swift-syntax.git",
      from: "603.0.0-latest"
    ),
  ],
  targets: [
$runtime_target_manifest
    .target(
      name: "AutoLogSwiftUI",
      dependencies: ["AutoLog"],
      swiftSettings: [.swiftLanguageMode(.v6)]
    ),
    .macro(
      name: "AutoLogMacro",
      dependencies: [
        .product(
          name: "SwiftSyntaxMacros",
          package: "swift-syntax"
        ),
        .product(
          name: "SwiftCompilerPlugin",
          package: "swift-syntax"
        )
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6)
      ]
    ),
    .target(
      name: "AutoLog",
      dependencies: [
        "AutoLogCore",
        "AutoLogMacro"
      ],
      path: "Sources/AutoLog",
      swiftSettings: [
        .swiftLanguageMode(.v6)
      ]
    ),
  ]
)
EOF

sed "s/__AUTOLOG_RELEASE_VERSION__/$VERSION/g" "$TOOL_DIR/templates/option-b-README.md" > "$OUTPUT_DIR/README.md"
mkdir -p "$OUTPUT_DIR/docs"
cp "$SOURCE_PACKAGE_DIR/Sources/AutoLog/Documentation.docc/MacroTrustAndCI.md" "$OUTPUT_DIR/docs/MacroTrustAndCI.md"

echo "Prepared Option B distribution package at $OUTPUT_DIR"

if [[ "$RUNTIME_SOURCE_FOR_SMOKE" == true ]]; then
  "$TOOL_DIR/validate-option-b-distribution.sh" \
    --package "$OUTPUT_DIR" \
    --allow-runtime-source
else
  "$TOOL_DIR/validate-option-b-distribution.sh" \
    --package "$OUTPUT_DIR"
fi
