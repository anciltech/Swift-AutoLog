import AutoLog
import Dispatch
import XCTest

final class AutoLogPerformanceTests: XCTestCase {
  fileprivate static let configuration = AutoLogConfiguration(
    emitStartEvents: false,
    measureTimingDefault: false
  )
  private static let iterations = 20_000
  private static let taskGroupIterations = 2_000
  private static let recordedScenarios = LockedScenarios()

  override class func tearDown() {
    recordedScenarios.printSummary()
    super.tearDown()
  }

  func testBaselineFunction() {
    measureScenario(named: "Baseline") {
      let fixture = PerformanceFixture()
      var checksum = 0

      for iteration in 0..<Self.iterations {
        checksum &+= fixture.baseline(iteration)
      }

      XCTAssertNotEqual(checksum, .min)
    }
  }

  func testLoggedFunctionWithoutTags() {
    measureScenario(named: "Logged without tags") {
      let fixture = PerformanceFixture()

      AutoLog.withRuntime(.benchmark) {
        var checksum = 0

        for iteration in 0..<Self.iterations {
          checksum &+= fixture.loggedWithoutTags(iteration)
        }

        XCTAssertNotEqual(checksum, .min)
      }
    }
  }

  func testLoggedFunctionWithVisibleTags() {
    measureScenario(named: "Logged with visible tags") {
      let fixture = PerformanceFixture()

      AutoLog.withRuntime(.benchmark) {
        var checksum = 0

        for iteration in 0..<Self.iterations {
          checksum &+= fixture.loggedWithVisibleTags(iteration)
        }

        XCTAssertNotEqual(checksum, .min)
      }
    }
  }

  func testLoggedFunctionWithRoutingTags() {
    measureScenario(named: "Logged with routing tags") {
      let fixture = PerformanceFixture()

      AutoLog.withRuntime(.benchmark) {
        var checksum = 0

        for iteration in 0..<Self.iterations {
          checksum &+= fixture.loggedWithRoutingTags(iteration)
        }

        XCTAssertNotEqual(checksum, .min)
      }
    }
  }

  func testLoggedFunctionWithMixedTags() {
    measureScenario(named: "Logged with mixed tags") {
      let fixture = PerformanceFixture()

      AutoLog.withRuntime(.benchmark) {
        var checksum = 0

        for iteration in 0..<Self.iterations {
          checksum &+= fixture.loggedWithMixedTags(iteration)
        }

        XCTAssertNotEqual(checksum, .min)
      }
    }
  }

  func testBaselineTaskGroupFunction() {
    measureScenario(named: "Baseline task group") {
      let fixture = PerformanceFixture()
      var checksum = 0

      for iteration in 0..<Self.taskGroupIterations {
        checksum &+= waitForAsyncResult {
          await fixture.baselineTaskGroup(iteration)
        }
      }

      XCTAssertNotEqual(checksum, .min)
    }
  }

  func testLoggedTaskGroupFunctionWithMixedTags() {
    measureScenario(named: "Logged task group") {
      let fixture = PerformanceFixture()

      AutoLog.withRuntime(.benchmark) {
        var checksum = 0

        for iteration in 0..<Self.taskGroupIterations {
          checksum &+= waitForAsyncResult {
            await fixture.loggedTaskGroupWithMixedTags(iteration)
          }
        }

        XCTAssertNotEqual(checksum, .min)
      }
    }
  }

  private func measureScenario(named scenario: String, _ operation: () -> Void) {
    let options = XCTMeasureOptions()
    options.iterationCount = 8
    var samples: [Double] = []

    measure(
      metrics: [
        XCTClockMetric(),
      ],
      options: options
    ) {
      let start = ContinuousClock.now
      operation()
      let duration = start.duration(to: .now).timeInterval
      samples.append(duration)
    }

    Self.recordedScenarios.record(
      ScenarioMeasurement(
        name: scenario,
        average: samples.average,
        relativeStandardDeviation: samples.relativeStandardDeviationPercent
      )
    )
  }

  private func waitForAsyncResult(
    _ operation: @escaping @Sendable () async -> Int
  ) -> Int {
    let semaphore = DispatchSemaphore(value: 0)
    let resultBox = AsyncResultBox<Int>()

    Task {
      resultBox.store(await operation())
      semaphore.signal()
    }

    semaphore.wait()
    return resultBox.load()
  }
}

private extension AutoLogRuntime {
  static var benchmark: Self {
    AutoLogRuntime(
      logger: BenchmarkLogger(),
      configuration: AutoLogPerformanceTests.configuration
    )
  }
}

private struct PerformanceFixture: Sendable {
  @inline(never)
  func baseline(_ value: Int) -> Int {
    controlFlowBody(value)
  }

  @inline(never)
  @Log
  func loggedWithoutTags(_ value: Int) -> Int {
    controlFlowBody(value)
  }

  @Tag("analytics")
  @Tag("critical-path")
  @inline(never)
  @Log
  func loggedWithVisibleTags(_ value: Int) -> Int {
    controlFlowBody(value)
  }

  @Tag(.splunk)
  @Tag(.firebase)
  @inline(never)
  @Log
  func loggedWithRoutingTags(_ value: Int) -> Int {
    controlFlowBody(value)
  }

  @Tag("analytics")
  @Tag("critical-path")
  @Tag(.console)
  @Tag(.splunk)
  @inline(never)
  @Log
  func loggedWithMixedTags(_ value: Int) -> Int {
    controlFlowBody(value)
  }

  @inline(never)
  func baselineTaskGroup(_ value: Int) async -> Int {
    await taskGroupBody(value)
  }

  @Tag("analytics")
  @Tag("critical-path")
  @Tag(.console)
  @Tag(.splunk)
  @inline(never)
  @Log
  func loggedTaskGroupWithMixedTags(_ value: Int) async -> Int {
    await taskGroupBody(value)
  }

  @inline(never)
  private func controlFlowBody(_ value: Int) -> Int {
    let candidate = value.isMultiple(of: 11) ? -value : value

    guard candidate >= 0 else {
      return fallbackValue(for: candidate)
    }

    var result = candidate &* 31

    if candidate.isMultiple(of: 3) {
      result &+= 7
    } else {
      result &-= 11
    }

    do {
      return try finalizedValue(for: result, original: candidate)
    } catch {
      return result ^ 0x0F0F
    }
  }

  @inline(never)
  private func taskGroupBody(_ value: Int) async -> Int {
    await withTaskGroup(of: Int.self, returning: Int.self) { group in
      group.addTask {
        self.controlFlowBody(value)
      }
      group.addTask {
        self.controlFlowBody(value &+ 1)
      }

      var total = 0

      for await partial in group {
        total &+= partial
      }

      return total
    }
  }

  @inline(never)
  private func finalizedValue(for result: Int, original: Int) throws -> Int {
    if original.isMultiple(of: 17) {
      throw BenchmarkFailure.synthetic
    }

    return result ^ 0x5A5A
  }

  @inline(never)
  private func fallbackValue(for candidate: Int) -> Int {
    candidate.magnitude.hashValue ^ 0x00FF
  }
}

private struct BenchmarkLogger: AutoLogger {
  let formatter: any AutoLogFormatter = CompactFormatter()
  let sinks: [any AutoLogEventSink] = [
    BenchmarkSink(route: .splunk),
    BenchmarkSink(route: .firebase),
  ]

  func emit(event: AutoLogEvent, configuration: AutoLogConfiguration) {
    let routes = event.routes

    if routes.isEmpty || routes.contains(.console) {
      _ = formatter.format(event: event, configuration: configuration)
    }

    for sink in sinks where routes.contains(sink.route) {
      sink.emit(event: event, configuration: configuration)
    }
  }
}

private struct BenchmarkSink: AutoLogEventSink {
  let route: AutoLogRoute

  func emit(event: AutoLogEvent, configuration: AutoLogConfiguration) {
    _ = event.visibleTags.count
    _ = configuration.measureTimingDefault
  }
}

private enum BenchmarkFailure: Error {
  case synthetic
}

private struct ScenarioMeasurement {
  let name: String
  let average: Double
  let relativeStandardDeviation: Double
}

private final class LockedScenarios: @unchecked Sendable {
  private let lock = NSLock()
  private var measurements: [ScenarioMeasurement] = []

  func record(_ measurement: ScenarioMeasurement) {
    lock.lock()
    measurements.append(measurement)
    lock.unlock()
  }

  func printSummary() {
    lock.lock()
    let snapshot = measurements
    measurements.removeAll(keepingCapacity: true)
    lock.unlock()

    guard
      let baseline = snapshot.first(where: { $0.name == "Baseline" }),
      !snapshot.isEmpty
    else {
      return
    }

    let rows = snapshot.map { measurement in
      ComparisonRow(
        scenario: measurement.name,
        average: measurement.average,
        relativeStandardDeviation: measurement.relativeStandardDeviation,
        slowdown: measurement.average / baseline.average
      )
    }

    let scenarioWidth = max(
      "Scenario".count,
      rows.map(\.scenario.count).max() ?? 0
    )

    let averageValues = rows.map {
      Self.formattedSeconds($0.average)
    }
    let averageWidth = max(
      "Average".count,
      averageValues.map(\.count).max() ?? 0
    )

    let slowdownValues = rows.map {
      Self.formattedMultiplier($0.slowdown)
    }
    let slowdownWidth = max(
      "Vs baseline".count,
      slowdownValues.map(\.count).max() ?? 0
    )

    let deviationValues = rows.map {
      Self.formattedPercent($0.relativeStandardDeviation)
    }
    let deviationWidth = max(
      "RSD".count,
      deviationValues.map(\.count).max() ?? 0
    )

    print("")
    print("AutoLog performance comparison")
    print(
      Self.formattedRow(
        scenario: "Scenario",
        average: "Average",
        slowdown: "Vs baseline",
        deviation: "RSD",
        scenarioWidth: scenarioWidth,
        averageWidth: averageWidth,
        slowdownWidth: slowdownWidth,
        deviationWidth: deviationWidth
      )
    )
    print(
      "\(String(repeating: "-", count: scenarioWidth))-\(String(repeating: "-", count: 3 + averageWidth))-\(String(repeating: "-", count: 3 + slowdownWidth))-\(String(repeating: "-", count: 3 + deviationWidth))"
    )

    for (index, row) in rows.enumerated() {
      print(
        Self.formattedRow(
          scenario: row.scenario,
          average: averageValues[index],
          slowdown: slowdownValues[index],
          deviation: deviationValues[index],
          scenarioWidth: scenarioWidth,
          averageWidth: averageWidth,
          slowdownWidth: slowdownWidth,
          deviationWidth: deviationWidth
        )
      )
    }
  }

  private static func formattedRow(
    scenario: String,
    average: String,
    slowdown: String,
    deviation: String,
    scenarioWidth: Int,
    averageWidth: Int,
    slowdownWidth: Int,
    deviationWidth: Int
  ) -> String {
    "\(scenario.rightPadded(to: scenarioWidth)) | \(average.leftPadded(to: averageWidth)) | \(slowdown.leftPadded(to: slowdownWidth)) | \(deviation.leftPadded(to: deviationWidth))"
  }

  private static func formattedSeconds(_ value: Double) -> String {
    String(format: "%.3fs", value)
  }

  private static func formattedMultiplier(_ value: Double) -> String {
    String(format: "%.1fx", value)
  }

  private static func formattedPercent(_ value: Double) -> String {
    String(format: "%.3f%%", value)
  }
}

private final class AsyncResultBox<Value>: @unchecked Sendable {
  private let lock = NSLock()
  private var value: Value?

  func store(_ newValue: Value) {
    lock.lock()
    value = newValue
    lock.unlock()
  }

  func load() -> Value {
    lock.lock()
    defer { lock.unlock() }
    return value!
  }
}

private struct ComparisonRow {
  let scenario: String
  let average: Double
  let relativeStandardDeviation: Double
  let slowdown: Double
}

private extension Array where Element == Double {
  var average: Double {
    guard !isEmpty else { return 0 }
    return reduce(0, +) / Double(count)
  }

  var relativeStandardDeviationPercent: Double {
    guard count > 1 else { return 0 }

    let mean = average
    let variance = reduce(0) { partialResult, value in
      let delta = value - mean
      return partialResult + (delta * delta)
    } / Double(count - 1)

    guard mean != 0 else { return 0 }
    return (variance.squareRoot() / mean) * 100
  }
}

private extension Duration {
  var timeInterval: TimeInterval {
    TimeInterval(components.seconds) +
      (TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000)
  }
}

private extension String {
  func leftPadded(to width: Int) -> String {
    guard count < width else { return self }
    return String(repeating: " ", count: width - count) + self
  }

  func rightPadded(to width: Int) -> String {
    guard count < width else { return self }
    return self + String(repeating: " ", count: width - count)
  }
}
