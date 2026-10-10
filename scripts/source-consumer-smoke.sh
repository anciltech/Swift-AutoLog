#!/usr/bin/env bash
set -euo pipefail

PACKAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE="${AUTOLOG_SOURCE_WORKSPACE:-$PACKAGE_DIR}"
CONSUMER_DIR="$WORKSPACE/.build/source-consumer"
CONSUMER_BUILD_DIR="$WORKSPACE/.build/source-consumer-build"
PACKAGE_URL=""
VERSION="0.11.0"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --package-url) PACKAGE_URL="${2:?Missing URL}"; shift 2 ;;
    --version) VERSION="${2:?Missing version}"; shift 2 ;;
    -h|--help)
      echo 'Usage: scripts/source-consumer-smoke.sh [--package-url URL --version VERSION]'
      exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Expected a semantic version.' >&2; exit 2; }
if [[ -n "$PACKAGE_URL" ]]; then
  [[ "$PACKAGE_URL" == 'https://github.com/anciltech/Swift-AutoLog.git' ]] || { echo 'Expected the public source repository.' >&2; exit 2; }
  DEPENDENCY=".package(url: \"$PACKAGE_URL\", exact: \"$VERSION\")"
else
  DEPENDENCY=".package(path: \"$PACKAGE_DIR\")"
fi
mkdir -p "$CONSUMER_DIR/Sources/SourceConsumer"
cat > "$CONSUMER_DIR/Package.swift" <<EOF
// swift-tools-version: 6.2
import PackageDescription
let package = Package(
  name: "SourceConsumer",
  platforms: [.macOS(.v15), .iOS(.v17), .watchOS(.v11)],
  products: [.executable(name: "SourceConsumer", targets: ["SourceConsumer"])],
  dependencies: [$DEPENDENCY],
  targets: [.executableTarget(
    name: "SourceConsumer",
    dependencies: [
      .product(name: "AutoLog", package: "swift-autolog"),
      .product(name: "AutoLogSwiftUI", package: "swift-autolog")
    ],
    swiftSettings: [.swiftLanguageMode(.v6)]
  )]
)
EOF

cat > "$CONSUMER_DIR/Sources/SourceConsumer/main.swift" <<'EOF'
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
  suiteName: "SourceConsumer.\(UUID().uuidString)"
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

print("Open-source consumer smoke passed")
EOF

swift run --jobs 4 --disable-keychain --disable-netrc \
  --package-path "$CONSUMER_DIR" --scratch-path "$CONSUMER_BUILD_DIR" SourceConsumer
