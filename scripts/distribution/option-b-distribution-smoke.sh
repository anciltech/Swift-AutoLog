#!/usr/bin/env bash
set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_PACKAGE_DIR="$(cd "$TOOL_DIR/../.." && pwd)"
ROOT_DIR="${AUTOLOG_DISTRIBUTION_WORKSPACE:-$SOURCE_PACKAGE_DIR}"
DIST_DIR="$ROOT_DIR/.build/option-b-public-package"
CONSUMER_DIR="$ROOT_DIR/.build/option-b-consumer"
CONSUMER_BUILD_DIR="$ROOT_DIR/.build/option-b-consumer-build"
RUNTIME_BINARY_PATH=""
PACKAGE_URL=""
VERSION="0.10.3"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runtime-binary-path)
      RUNTIME_BINARY_PATH="${2:-}"
      shift 2
      ;;
    --package-url)
      PACKAGE_URL="${2:?Missing package URL}"
      shift 2
      ;;
    --version)
      VERSION="${2:?Missing release version}"
      shift 2
      ;;
    -h|--help)
      cat <<'EOF'
Usage:
  scripts/option-b-distribution-smoke.sh
  scripts/option-b-distribution-smoke.sh --runtime-binary-path PATH
  scripts/option-b-distribution-smoke.sh --package-url URL --version VERSION

Without --runtime-binary-path, the smoke uses runtime source as a temporary
stand-in so the package split can be verified before a binary exists.
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -n "$RUNTIME_BINARY_PATH" && -n "$PACKAGE_URL" ]]; then
  echo "Choose a local runtime or a published package, not both." >&2
  exit 2
fi
if [[ -z "$PACKAGE_URL" ]]; then
  rm -rf "$DIST_DIR"
fi
if [[ -n "$PACKAGE_URL" ]]; then
  PACKAGE_ID="$(basename "$PACKAGE_URL" .git | tr '[:upper:]' '[:lower:]')"
  DEPENDENCY=".package(url: \"$PACKAGE_URL\", exact: \"$VERSION\")"
elif [[ -n "$RUNTIME_BINARY_PATH" ]]; then
  "$TOOL_DIR/prepare-option-b-distribution.sh" \
    --output "$DIST_DIR" --version "$VERSION" \
    --runtime-binary-path "$RUNTIME_BINARY_PATH"
else
  "$TOOL_DIR/prepare-option-b-distribution.sh" \
    --output "$DIST_DIR" --version "$VERSION" \
    --runtime-source-for-smoke
fi

if [[ -z "$PACKAGE_URL" ]]; then
  PACKAGE_ID="option-b-public-package"
  DEPENDENCY='.package(path: "../option-b-public-package")'
fi
if [[ -n "$RUNTIME_BINARY_PATH" ]]; then
  # Force the consumer to compile the public text interfaces, proving that the
  # release is not relying on compiler-specific cached .swiftmodule files.
  find "$DIST_DIR/Artifacts" -type f -name '*.swiftmodule' -delete
fi
rm -rf "$CONSUMER_DIR" "$CONSUMER_BUILD_DIR"
mkdir -p "$CONSUMER_DIR/Sources/OptionBConsumer"

cat > "$CONSUMER_DIR/Package.swift" <<EOF
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "OptionBConsumer",
  platforms: [
    .macOS(.v15),
    .iOS(.v17),
    .watchOS(.v11),
  ],
  products: [
    .executable(name: "OptionBConsumer", targets: ["OptionBConsumer"]),
  ],
  dependencies: [
    $DEPENDENCY,
  ],
  targets: [
    .executableTarget(
      name: "OptionBConsumer",
      dependencies: [
        .product(name: "AutoLog", package: "$PACKAGE_ID"),
        .product(name: "AutoLogSwiftUI", package: "$PACKAGE_ID"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
  ]
)
EOF

cat > "$CONSUMER_DIR/Sources/OptionBConsumer/main.swift" <<'EOF'
import AutoLog
import AutoLogSwiftUI
import SwiftUI
import Foundation

enum ConsumerError: Error {
  case expectedFailure
}

private final class EventStore: @unchecked Sendable {
  private let lock = NSLock()
  private var events: [AutoLogEvent] = []

  func record(_ event: AutoLogEvent) {
    lock.lock()
    events.append(event)
    lock.unlock()
  }

  func snapshot() -> [AutoLogEvent] {
    lock.lock()
    defer { lock.unlock() }
    return events
  }
}

private struct BackendSink: AutoLogEventSink {
  let route: AutoLogRoute = .splunk
  let store: EventStore

  func emit(event: AutoLogEvent, configuration _: AutoLogConfiguration) {
    store.record(event)
  }
}

@AutoLog(emit: .failures, measure: false)
private struct CustomerService {
  @Tag(.splunk)
  func run(shouldFail: Bool) throws -> String {
    guard !shouldFail else {
      throw ConsumerError.expectedFailure
    }

    return "ok"
  }
}

@AutoLog
private struct QuickStartService {
  func greet(_ name: String) -> String { "Hello, \(name)" }
}

@MainActor
private struct ConsumerView: View {
  var body: some View {
    Button.log("Greet") { _ = QuickStartService().greet("World") }
      .taskLog("Load") { _ = QuickStartService().greet("Async") }
      .taskLog("Reload", id: "one") { _ = QuickStartService().greet("Reload") }
  }
}

private final class ActorState {
  var value = 0
}

@MainActor
private func verifyCallerIsolation() async {
  let state = ActorState()
  let depth = await AutoLog.withCallSiteDepth(2) {
    await Task.yield()
    state.value += 1
    return state
  }
  let interaction = await AutoLogInteraction.system("Actor check").log {
    await Task.yield()
    state.value += 1
    return state
  }
  let task = await AutoLog.logTask("Actor check") {
    await Task.yield()
    state.value += 1
    return state
  }
  guard depth === state, interaction === state, task === state, state.value == 3 else {
    fatalError("Async wrappers failed caller-isolation check")
  }
}

await verifyCallerIsolation()

private let store = EventStore()
private let configurationStore = AutoLogConfigurationStore(
  suiteName: "OptionBConsumer.\(UUID().uuidString)"
)

// Verify the documented default bootstrap and an ordinary macro call first.
AutoLog.start(configurationStore: configurationStore)
guard QuickStartService().greet("World") == "Hello, World" else {
  fatalError("Quick start returned the wrong value")
}
AutoLog.start(
  configuration: AutoLogConfiguration(outputs: [
    AutoLogOutput(name: "Backend", route: .splunk,
                  eventTypes: [.success, .failure], parameterPrivacy: .include)
  ]),
  sinks: [BackendSink(store: store)],
  configurationStore: configurationStore
)

private let service = CustomerService()
_ = try service.run(shouldFail: false)

do {
  _ = try service.run(shouldFail: true)
  fatalError("Expected failure")
} catch ConsumerError.expectedFailure {
  // Expected.
}

let events = store.snapshot()
let successCount = events.filter { $0.outputEventType == .success }.count
let failureCount = events.filter { $0.outputEventType == .failure }.count

guard successCount == 0, failureCount == 1 else {
  fatalError("Expected only one failure event, got success=\(successCount) failure=\(failureCount)")
}

print("Option B distribution smoke passed")
EOF

# The public customer endpoint must work without credentials. Disable SwiftPM
# credential stores as well as Git configuration in the publisher/recheck lane.
swift run --disable-keychain --disable-netrc \
  --package-path "$CONSUMER_DIR" \
  --scratch-path "$CONSUMER_BUILD_DIR" \
  OptionBConsumer
