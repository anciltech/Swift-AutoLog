import AutoLog
import AutoLogSwiftLog
import Foundation
import Logging
import Testing

@Suite(.serialized)
struct SwiftLogAutoLoggerTests {
  @Test
  func swiftLogBridge_forwardsMatchingEventsWithMetadata() {
    let store = RecordingLogStore()
    let logger = Logging.Logger(label: "SwiftLogAutoLoggerTests") { _ in
      RecordingLogHandler(store: store)
    }
    let bridge = SwiftLogAutoLogger(
      logger: logger,
      formatter: CompactFormatter(
        format: LogFormat(
          mainLine: [.typeName, .dotSeparator, .functionName]
        )
      ),
      metadata: [
        "app": .string("smoke")
      ]
    )
    let configuration = AutoLogConfiguration(
      outputs: [
        AutoLogOutput(
          name: "SwiftLog",
          route: .splunk,
          eventTypes: [.failure],
          parameterPrivacy: .omit
        )
      ]
    )

    bridge.emit(
      event: AutoLogEvent(
        location: "App/PaymentService.swift:12:3",
        declaration: "func submit(orderID: String) throws -> Receipt",
        parameters: ["orderID": "A100"],
        result: .failure(TestError.expected),
        tags: [AutoLogRoute.splunk]
      ),
      configuration: configuration
    )

    #expect(store.records.count == 1)
    #expect(store.records.first?.level == .error)
    #expect(store.records.first?.metadata["app"] == .string("smoke"))
    #expect(store.records.first?.metadata["autolog.event"] == .string("failure"))
    #expect(store.records.first?.metadata["autolog.route"] == .string("splunk"))
    #expect(store.records.first?.metadata["autolog.type"] == .string("PaymentService"))
    #expect(store.records.first?.message.description.contains("submit") == true)
  }

  @Test
  func swiftLogBridge_respectsOutputPrivacyAndFilters() {
    let store = RecordingLogStore()
    let logger = Logging.Logger(label: "SwiftLogAutoLoggerTests") { _ in
      RecordingLogHandler(store: store)
    }
    let bridge = SwiftLogAutoLogger(logger: logger)
    let configuration = AutoLogConfiguration(
      outputs: [
        AutoLogOutput(
          name: "SwiftLog",
          route: .splunk,
          eventTypes: [.success],
          parameterPrivacy: .omit
        )
      ]
    )

    bridge.emit(
      event: AutoLogEvent(
        location: "App/PaymentService.swift:12:3",
        declaration: "func submit(orderID: String) throws -> Receipt",
        parameters: ["orderID": "A100"],
        result: .success("receipt"),
        tags: [AutoLogRoute.splunk]
      ),
      configuration: configuration
    )

    #expect(store.records.count == 1)
    #expect(store.records.first?.message.description.contains("A100") == false)

    bridge.emit(
      event: AutoLogEvent(
        location: "App/PaymentService.swift:12:3",
        declaration: "func submit(orderID: String) throws -> Receipt",
        result: .failure(TestError.expected),
        tags: [AutoLogRoute.splunk]
      ),
      configuration: configuration
    )

    #expect(store.records.count == 1)
  }

  @Test
  func swiftLogBridge_mapsEventLevels() {
    #expect(
      SwiftLogAutoLogger.level(
        for: AutoLogEvent(
          level: LogLevel.warning,
          location: "App/PaymentService.swift:12:3",
          declaration: "func submit()"
        )
      ) == .warning
    )

    #expect(
      SwiftLogAutoLogger.level(
        for: AutoLogEvent(
          location: "App/PaymentService.swift:12:3",
          declaration: "func submit()",
          result: .failure(TestError.expected)
        )
      ) == .error
    )
  }
}

private enum TestError: Error {
  case expected
}

private final class RecordingLogStore: @unchecked Sendable {
  private let lock = NSLock()
  private var storage: [Record] = []

  struct Record {
    var level: Logging.Logger.Level
    var message: Logging.Logger.Message
    var metadata: Logging.Logger.Metadata
  }

  var records: [Record] {
    lock.lock()
    defer { lock.unlock() }
    return storage
  }

  func append(_ record: Record) {
    lock.lock()
    storage.append(record)
    lock.unlock()
  }
}

private struct RecordingLogHandler: LogHandler {
  var metadata: Logging.Logger.Metadata = [:]
  var logLevel: Logging.Logger.Level = .trace
  let store: RecordingLogStore

  subscript(metadataKey key: String) -> Logging.Logger.Metadata.Value? {
    get { metadata[key] }
    set { metadata[key] = newValue }
  }

  func log(event: LogEvent) {
    var mergedMetadata = self.metadata
    for (key, value) in event.metadata ?? [:] {
      mergedMetadata[key] = value
    }

    store.append(
      RecordingLogStore.Record(
        level: event.level,
        message: event.message,
        metadata: mergedMetadata
      )
    )
  }
}
