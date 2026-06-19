import AutoLog
import Logging

/// An ``AutoLogger`` bridge that forwards AutoLog events into Apple's swift-log
/// ``Logging/Logger`` facade.
///
/// Use this when an app already standardizes on swift-log and wants AutoLog's
/// macro-generated function-boundary events to flow through the same logging
/// backend.
public struct SwiftLogAutoLogger: AutoLogger {
  public var logger: Logging.Logger
  public var formatter: any AutoLogFormatter
  public var metadata: Logging.Logger.Metadata

  public init(
    logger: Logging.Logger = Logging.Logger(label: "SwiftAutoLog"),
    formatter: any AutoLogFormatter = CompactFormatter(),
    metadata: Logging.Logger.Metadata = [:]
  ) {
    self.logger = logger
    self.formatter = formatter
    self.metadata = metadata
  }

  public func emit(event: AutoLogEvent, configuration: AutoLogConfiguration) {
    let matchedOutputs = configuration.effectiveOutputs.filter { $0.matches(event) }
    guard !matchedOutputs.isEmpty else { return }

    for output in matchedOutputs {
      let outputConfiguration = configuration.applying(output: output)
      let event = event.applyingPrivacy(output)
      var logger = logger

      for (key, value) in metadata {
        logger[metadataKey: key] = value
      }

      for (key, value) in Self.metadata(for: event, output: output) {
        logger[metadataKey: key] = value
      }

      logger.log(
        level: Self.level(for: event),
        "\(formatter.format(event: event, configuration: outputConfiguration))"
      )
    }
  }

  public static func level(for event: AutoLogEvent) -> Logging.Logger.Level {
    if let level = event.level as? LogLevel {
      switch level {
      case .start, .success, .update:
        return .info
      case .warning:
        return .warning
      case .failure:
        return .error
      }
    }

    if event.outputEventType == .warning {
      return .warning
    }

    if event.outputEventType == .failure {
      return .error
    }

    return .info
  }

  public static func metadata(
    for event: AutoLogEvent,
    output: AutoLogOutput
  ) -> Logging.Logger.Metadata {
    var metadata: Logging.Logger.Metadata = [
      "autolog.output": .string(output.name),
      "autolog.route": .string(output.route.rawValue),
      "autolog.event": .string(event.outputEventType.rawValue),
      "autolog.type": .string(event.inferredTypeName),
      "autolog.function": .string(event.functionName),
      "autolog.location": .string(event.shortLocation),
    ]

    if !event.visibleTags.isEmpty {
      metadata["autolog.tags"] = .string(
        event.visibleTags
          .map { String(describing: $0) }
          .joined(separator: ",")
      )
    }

    return metadata
  }
}
