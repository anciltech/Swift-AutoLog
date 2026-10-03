#!/usr/bin/env bash
set -euo pipefail

# Run only when publishing a customer release is authorized.
TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_PACKAGE_DIR="$(cd "$TOOL_DIR/../.." && pwd)"
ROOT_DIR="${AUTOLOG_DISTRIBUTION_WORKSPACE:-$SOURCE_PACKAGE_DIR}"
VERSION="${1:?Usage: scripts/publish-option-b-distribution.sh VERSION ARTIFACT_DIR}"
ARTIFACT_DIR="${2:?Missing artifact directory}"
REPOSITORY="anciltech/Swift-AutoLog-Distribution"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Expected a semantic version." >&2; exit 2; }
ARTIFACT_DIR="$(cd "$ARTIFACT_DIR" && pwd)"
ARCHIVE="$ARTIFACT_DIR/AutoLogRuntime.xcframework.zip"
[[ -f "$ARCHIVE" ]] || { echo "Build AutoLogRuntime.xcframework.zip first." >&2; exit 1; }
CHECKSUM="$(swift package compute-checksum "$ARCHIVE")"
DIST_DIR="$ROOT_DIR/.build/option-b-release-$VERSION"
[[ ! -e "$DIST_DIR" ]] || { echo "Release staging directory already exists: $DIST_DIR" >&2; exit 1; }

# Verify the actual binary consumer before creating any public repository.
"$TOOL_DIR/option-b-distribution-smoke.sh" \
  --runtime-binary-path "$ARTIFACT_DIR/AutoLogRuntime.xcframework"
"$TOOL_DIR/prepare-option-b-distribution.sh" \
  --output "$DIST_DIR" \
  --runtime-binary-url "https://github.com/$REPOSITORY/releases/download/$VERSION/AutoLogRuntime.xcframework.zip" \
  --checksum "$CHECKSUM"
# Keep the customer's install minimum aligned with the release being published.
sed -i '' "s/0\.10\.2/$VERSION/g" "$DIST_DIR/README.md"
"$TOOL_DIR/validate-option-b-distribution.sh" --package "$DIST_DIR"

cat > "$DIST_DIR/RELEASE.md" <<NOTES
# Swift AutoLog $VERSION

Install: https://github.com/$REPOSITORY.git

Products: AutoLog and optional AutoLogSwiftUI.
Platforms: iOS 17+, macOS 15+, watchOS 11+, and simulators.
Toolchain: Xcode 27 / Swift 6.4 or newer.

The runtime is a static XCFramework; its implementation source is excluded.
Macro implementations and SwiftUI convenience wrappers remain source targets.

Runtime SHA-256: $CHECKSUM
Private source revision: $(git -C "$SOURCE_PACKAGE_DIR" rev-parse HEAD)
NOTES

if gh repo view "$REPOSITORY" --json visibility --jq .visibility > "$DIST_DIR/../option-b-repository-visibility.txt" 2>/dev/null; then
  [[ "$(cat "$DIST_DIR/../option-b-repository-visibility.txt")" == PUBLIC ]] || {
    echo "Existing distribution repository must already be public; refusing to change visibility." >&2
    exit 1
  }
  # Do not replace an existing repository's history or overwrite a release.
  git clone "https://github.com/$REPOSITORY.git" "$DIST_DIR/../option-b-history-$VERSION"
  PREVIOUS="$DIST_DIR/../option-b-history-$VERSION"
  if git -C "$PREVIOUS" rev-parse "refs/tags/$VERSION" >/dev/null 2>&1; then
    echo "Release tag $VERSION already exists." >&2
    exit 1
  fi
  # Preserve files outside the generator-owned package surface (for example,
  # existing CI workflows); replace generated targets rather than restoring
  # removed macro files from a previous release.
  for extra in "$PREVIOUS"/* "$PREVIOUS"/.[!.]*; do
    [[ -e "$extra" ]] || continue
    case "$(basename "$extra")" in
      .git|Package.swift|README.md|LICENSE|RELEASE.md|Sources|Artifacts|docs) continue ;;
    esac
    cp -R "$extra" "$DIST_DIR/"
  done
  cp -R "$PREVIOUS/.git" "$DIST_DIR/.git"
  "$TOOL_DIR/validate-option-b-distribution.sh" --package "$DIST_DIR"
else
  # A lookup error is not proof that a repository is absent. Creation itself
  # must succeed before any content can be pushed.
  gh repo create "$REPOSITORY" --public --description 'Swift AutoLog: Swift macros with a precompiled logging runtime for Apple apps'
  git -C "$DIST_DIR" init -b main
  git -C "$DIST_DIR" remote add origin "https://github.com/$REPOSITORY.git"
fi

git -C "$DIST_DIR" add --all
git -C "$DIST_DIR" commit -m "release: publish protected runtime $VERSION"
git -C "$DIST_DIR" tag -a "$VERSION" -m "Swift AutoLog $VERSION"
git -C "$DIST_DIR" push origin HEAD:main "refs/tags/$VERSION"
gh release create "$VERSION" "$ARCHIVE" \
  --repo "$REPOSITORY" --title "Swift AutoLog $VERSION" --notes-file "$DIST_DIR/RELEASE.md"

# Prove the hosted artifact and source package are reachable without credentials.
curl --fail --location --silent --show-error --retry 5 --retry-all-errors --retry-delay 2 \
  "https://github.com/$REPOSITORY/releases/download/$VERSION/AutoLogRuntime.xcframework.zip" \
  --output "$ARTIFACT_DIR/anonymous-download.zip"
[[ "$(swift package compute-checksum "$ARTIFACT_DIR/anonymous-download.zip")" == "$CHECKSUM" ]]
GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0 \
  "$TOOL_DIR/option-b-distribution-smoke.sh" \
  --package-url "https://github.com/$REPOSITORY.git" --version "$VERSION"
echo "Published and verified https://github.com/$REPOSITORY/releases/tag/$VERSION"
