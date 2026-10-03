#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/validate-option-b-distribution.sh --package DIR [--allow-runtime-source]

Validates the Option B customer package shape.

Release packages should not pass --allow-runtime-source. Smoke packages that
intentionally copy runtime source can pass it so package-shape tests still work
before a binary artifact exists.
EOF
}

PACKAGE_DIR=""
ALLOW_RUNTIME_SOURCE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --package)
      PACKAGE_DIR="${2:-}"
      shift 2
      ;;
    --allow-runtime-source)
      ALLOW_RUNTIME_SOURCE=true
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

if [[ -z "$PACKAGE_DIR" ]]; then
  echo "--package is required" >&2
  usage >&2
  exit 2
fi

if [[ ! -f "$PACKAGE_DIR/Package.swift" ]]; then
  echo "Missing Package.swift in $PACKAGE_DIR" >&2
  exit 1
fi

if [[ ! -f "$PACKAGE_DIR/Sources/AutoLog/Macros.swift" ]]; then
  echo "Missing AutoLog source shim" >&2
  exit 1
fi

if [[ ! -d "$PACKAGE_DIR/Sources/AutoLogMacro" ]]; then
  echo "Missing public AutoLogMacro source target" >&2
  exit 1
fi

if [[ "$ALLOW_RUNTIME_SOURCE" == true ]]; then
  if [[ ! -d "$PACKAGE_DIR/Sources/AutoLogCore" ]]; then
    echo "Smoke package expected Sources/AutoLogCore" >&2
    exit 1
  fi
else
  if [[ -d "$PACKAGE_DIR/Sources/AutoLogCore" ]]; then
    echo "Release package must not include Sources/AutoLogCore" >&2
    exit 1
  fi

  if ! grep -q 'binaryTarget(' "$PACKAGE_DIR/Package.swift"; then
    echo "Release package must declare AutoLogCore as a binaryTarget" >&2
    exit 1
  fi
fi

if find "$PACKAGE_DIR/Sources/AutoLog" -type f ! -name 'Macros.swift' | grep -q .; then
  echo "AutoLog shim must only contain public macro declarations" >&2
  exit 1
fi

if ! grep -q 'name: "AutoLogCore"' "$PACKAGE_DIR/Package.swift"; then
  echo "Package.swift must declare an AutoLogCore target" >&2
  exit 1
fi

if ! grep -q '@_exported public import AutoLogCore' "$PACKAGE_DIR/Sources/AutoLog/Macros.swift"; then
  echo "AutoLog shim must re-export AutoLogCore" >&2
  exit 1
fi

# Parse the manifest instead of trusting text matches alone. dump-package does
# not resolve or download dependencies.
MANIFEST_JSON="$(swift package --package-path "$PACKAGE_DIR" dump-package)"
printf '%s' "$MANIFEST_JSON" | python3 -c '
import json, re, sys
from pathlib import Path
manifest = json.load(sys.stdin)
root = Path(sys.argv[1])
smoke = sys.argv[2] == "true"
targets = {t["name"]: t for t in manifest["targets"]}
expected = {"AutoLog", "AutoLogMacro", "AutoLogSwiftUI", "AutoLogCore"}
assert set(targets) == expected, "Unexpected targets in customer package"
assert {p["name"] for p in manifest["products"]} == {"AutoLog", "AutoLogSwiftUI"}, "Missing public products"
assert (root / "LICENSE").is_file(), "License missing"
allowed = expected if smoke else expected - {"AutoLogCore"}
assert {p.name for p in (root / "Sources").iterdir()} == allowed, "Unexpected source directory"
runtime = targets["AutoLogCore"]
if not smoke:
    assert runtime["type"] == "binary", "Runtime must be binary"
    if runtime.get("url"):
        assert runtime["url"].startswith("https://"), "Binary URL must use HTTPS"
        assert re.fullmatch(r"[0-9a-f]{64}", runtime.get("checksum", "")), "Invalid binary checksum"
    else:
        path = Path(runtime["path"])
        assert not path.is_absolute() and ".." not in path.parts, "Binary path must be inside package"
        assert (root / path / "Info.plist").is_file(), "XCFramework missing"
        assert not list((root / path).rglob("*.swift")), "Binary artifact contains Swift implementation source"
' "$PACKAGE_DIR" "$ALLOW_RUNTIME_SOURCE"
echo "Option B distribution package validated: $PACKAGE_DIR"
