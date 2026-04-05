import AutoLog
import XCTest

final class AutoLogPerformanceTests: XCTestCase {
  fileprivate static let configuration = AutoLogConfiguration(
    emitStartEvents: false,
    measureTimingDefault: false
  )
  private static let iterations = 20_000

  func testBaselineFunction() {
    measureScenario {
      let fixture = PerformanceFixture()
      var checksum = 0

      for iteration in 0..<Self.iterations {
        checksum &+= fixture.baseline(iteration)
      }

      XCTAssertNotEqual(checksum, .min)
    }
  }

  func testLoggedFunctionWithoutTags() {
    measureScenario {
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
    measureScenario {
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
    measureScenario {
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
    measureScenario {
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

  private func measureScenario(_ operation: () -> Void) {
    let options = XCTMeasureOptions()
    options.iterationCount = 8

    measure(
      metrics: [
        XCTClockMetric(),
      ],
      options: options
    ) {
      operation()
    }
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

private struct PerformanceFixture {
  @inline(never)
  func baseline(_ value: Int) -> Int {
    sharedBody(value)
  }

  @inline(never)
  @Log
  func loggedWithoutTags(_ value: Int) -> Int {
    sharedBody(value)
  }

  @Tag("analytics")
  @Tag("critical-path")
  @inline(never)
  @Log
  func loggedWithVisibleTags(_ value: Int) -> Int {
    sharedBody(value)
  }

  @Tag(.splunk)
  @Tag(.firebase)
  @inline(never)
  @Log
  func loggedWithRoutingTags(_ value: Int) -> Int {
    sharedBody(value)
  }

  @Tag("analytics")
  @Tag("critical-path")
  @Tag(.console)
  @Tag(.splunk)
  @inline(never)
  @Log
  func loggedWithMixedTags(_ value: Int) -> Int {
    sharedBody(value)
  }

  @inline(never)
  private func sharedBody(_ value: Int) -> Int {
    var result = value &* 31

    if value.isMultiple(of: 3) {
      result &+= 7
    } else {
      result &-= 11
    }

    return result ^ 0x5A5A
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
