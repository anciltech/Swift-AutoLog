import AutoLog
import Dispatch
import XCTest

final class AutoLogPerformanceTests: XCTestCase {
  fileprivate static let configuration = AutoLogConfiguration(
    emitStartEvents: false,
    measureTimingDefault: false
  )
  fileprivate static let iterations = 20_000
  fileprivate static let taskGroupIterations = 2_000
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

private enum ScenarioFamily {
  case sync
  case taskGroup

  var label: String {
    switch self {
    case .sync:
      "sync"
    case .taskGroup:
      "task-group"
    }
  }
}

private struct ScenarioDescriptor {
  let family: ScenarioFamily
  let iterations: Int
  let addedWork: String
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

    guard !snapshot.isEmpty else {
      return
    }

    var baselines: [ScenarioFamily: Double] = [:]
    for measurement in snapshot where Self.isBaseline(measurement.name) {
      let descriptor = Self.descriptor(for: measurement.name)
      baselines[descriptor.family] = measurement.average
    }

    let rows: [ComparisonRow] = snapshot.compactMap { measurement in
      let descriptor = Self.descriptor(for: measurement.name)
      guard let baselineAverage = baselines[descriptor.family] else { return nil }

      let addedTime = measurement.average - baselineAverage

      return ComparisonRow(
        scenario: measurement.name,
        family: descriptor.family.label,
        average: measurement.average,
        addedTime: addedTime,
        slowdown: measurement.average / baselineAverage,
        perIterationOverhead: addedTime / Double(descriptor.iterations),
        relativeStandardDeviation: measurement.relativeStandardDeviation,
        addedWork: descriptor.addedWork
      )
    }

    let scenarioWidth = max("Scenario".count, rows.map { $0.scenario.count }.max() ?? 0)
    let familyWidth = max("Family".count, rows.map { $0.family.count }.max() ?? 0)

    let averageValues = rows.map { Self.formattedSeconds($0.average) }
    let averageWidth = max("Average".count, averageValues.map { $0.count }.max() ?? 0)

    let addedValues = rows.map { Self.formattedSignedSeconds($0.addedTime) }
    let addedWidth = max("Added".count, addedValues.map { $0.count }.max() ?? 0)

    let slowdownValues = rows.map { Self.formattedMultiplier($0.slowdown) }
    let slowdownWidth = max("Vs family base".count, slowdownValues.map { $0.count }.max() ?? 0)

    let perIterationValues = rows.map { Self.formattedPerIteration($0.perIterationOverhead) }
    let perIterationWidth = max("Overhead/call".count, perIterationValues.map { $0.count }.max() ?? 0)

    let deviationValues = rows.map { Self.formattedPercent($0.relativeStandardDeviation) }
    let deviationWidth = max("RSD".count, deviationValues.map { $0.count }.max() ?? 0)

    let addedWorkWidth = max("What adds time".count, rows.map { $0.addedWork.count }.max() ?? 0)

    print("")
    print("AutoLog performance comparison")
    print("RSD = relative standard deviation; lower means the timings were more stable across measured runs.")
    print("Added and Overhead/call are measured against the matching family baseline (`sync` or `task-group`).")
    print(
      Self.formattedRow(
        scenario: "Scenario",
        family: "Family",
        average: "Average",
        added: "Added",
        slowdown: "Vs family base",
        perIteration: "Overhead/call",
        deviation: "RSD",
        addedWork: "What adds time",
        scenarioWidth: scenarioWidth,
        familyWidth: familyWidth,
        averageWidth: averageWidth,
        addedWidth: addedWidth,
        slowdownWidth: slowdownWidth,
        perIterationWidth: perIterationWidth,
        deviationWidth: deviationWidth,
        addedWorkWidth: addedWorkWidth
      )
    )
    print(
      "\(String(repeating: "-", count: scenarioWidth))-\(String(repeating: "-", count: 3 + familyWidth))-\(String(repeating: "-", count: 3 + averageWidth))-\(String(repeating: "-", count: 3 + addedWidth))-\(String(repeating: "-", count: 3 + slowdownWidth))-\(String(repeating: "-", count: 3 + perIterationWidth))-\(String(repeating: "-", count: 3 + deviationWidth))-\(String(repeating: "-", count: 3 + addedWorkWidth))"
    )

    for (index, row) in rows.enumerated() {
      print(
        Self.formattedRow(
          scenario: row.scenario,
          family: row.family,
          average: averageValues[index],
          added: addedValues[index],
          slowdown: slowdownValues[index],
          perIteration: perIterationValues[index],
          deviation: deviationValues[index],
          addedWork: row.addedWork,
          scenarioWidth: scenarioWidth,
          familyWidth: familyWidth,
          averageWidth: averageWidth,
          addedWidth: addedWidth,
          slowdownWidth: slowdownWidth,
          perIterationWidth: perIterationWidth,
          deviationWidth: deviationWidth,
          addedWorkWidth: addedWorkWidth
        )
      )
    }
  }

  private static func descriptor(for scenario: String) -> ScenarioDescriptor {
    switch scenario {
    case "Baseline":
      ScenarioDescriptor(
        family: .sync,
        iterations: AutoLogPerformanceTests.iterations,
        addedWork: "Reference body with guard, if/else, do/catch only"
      )
    case "Logged without tags":
      ScenarioDescriptor(
        family: .sync,
        iterations: AutoLogPerformanceTests.iterations,
        addedWork: "Macro wrapper, AutoLogEvent capture, formatter path"
      )
    case "Logged with visible tags":
      ScenarioDescriptor(
        family: .sync,
        iterations: AutoLogPerformanceTests.iterations,
        addedWork: "Logged path plus visible tag capture and tag-line formatting"
      )
    case "Logged with routing tags":
      ScenarioDescriptor(
        family: .sync,
        iterations: AutoLogPerformanceTests.iterations,
        addedWork: "Logged path plus route filtering and sink dispatch checks"
      )
    case "Logged with mixed tags":
      ScenarioDescriptor(
        family: .sync,
        iterations: AutoLogPerformanceTests.iterations,
        addedWork: "Formatter work, visible tags, route checks, and sink traversal"
      )
    case "Baseline task group":
      ScenarioDescriptor(
        family: .taskGroup,
        iterations: AutoLogPerformanceTests.taskGroupIterations,
        addedWork: "Reference async body with TaskGroup scheduling and result aggregation"
      )
    case "Logged task group":
      ScenarioDescriptor(
        family: .taskGroup,
        iterations: AutoLogPerformanceTests.taskGroupIterations,
        addedWork: "TaskGroup baseline plus macro wrapper, event capture, formatting, and routing"
      )
    default:
      ScenarioDescriptor(
        family: .sync,
        iterations: AutoLogPerformanceTests.iterations,
        addedWork: "Unclassified benchmark work"
      )
    }
  }

  private static func isBaseline(_ scenario: String) -> Bool {
    scenario == "Baseline" || scenario == "Baseline task group"
  }

  private static func formattedRow(
    scenario: String,
    family: String,
    average: String,
    added: String,
    slowdown: String,
    perIteration: String,
    deviation: String,
    addedWork: String,
    scenarioWidth: Int,
    familyWidth: Int,
    averageWidth: Int,
    addedWidth: Int,
    slowdownWidth: Int,
    perIterationWidth: Int,
    deviationWidth: Int,
    addedWorkWidth: Int
  ) -> String {
    "\(scenario.rightPadded(to: scenarioWidth)) | \(family.rightPadded(to: familyWidth)) | \(average.leftPadded(to: averageWidth)) | \(added.leftPadded(to: addedWidth)) | \(slowdown.leftPadded(to: slowdownWidth)) | \(perIteration.leftPadded(to: perIterationWidth)) | \(deviation.leftPadded(to: deviationWidth)) | \(addedWork.rightPadded(to: addedWorkWidth))"
  }

  private static func formattedSeconds(_ value: Double) -> String {
    String(format: "%.3fs", value)
  }

  private static func formattedSignedSeconds(_ value: Double) -> String {
    String(format: "%+.3fs", value)
  }

  private static func formattedMultiplier(_ value: Double) -> String {
    String(format: "%.1fx", value)
  }

  private static func formattedPerIteration(_ value: Double) -> String {
    String(format: "%+.2fµs", value * 1_000_000)
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
  let family: String
  let average: Double
  let addedTime: Double
  let slowdown: Double
  let perIterationOverhead: Double
  let relativeStandardDeviation: Double
  let addedWork: String
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
