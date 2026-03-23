#if canImport(OSLog)
@_exported public import OSLog
#endif

/// A protocol that provides instances of conforming types with the ability to
/// handle emitted events.
public protocol AutoLogger: Sendable {
  /// Handle an emitted event.
  ///
  /// Events are currently emitted in the following cases:
  ///   - When the function completes successfully
  ///   - When the function throws an error.
  ///
  func emit(event: AutoLogEvent)
}

// TODO: 23122K - Make this type conform to Sendable and use CustomDebugStringConvertible
/// A type representing captured metadata from an invoked function.
public struct AutoLogEvent: CustomStringConvertible, CustomDebugStringConvertible {
  /// The logging level associated with the event.
  public let level: (any Levelable)?

  /// The interaction source that triggered this event, if any.
  public let source: (any Sourceable)?

  /// The source location of the invoked function.
  public let location: String

  /// A representation of a function's name and return
  /// type, excluding parameters and body.
  public let declaration: String

  /// A set of arguments passed to a function, associated
  /// with their parameter labels.
  public var parameters: [String: Any]

  /// The result of the function.
  public var result: Result<Any, any Error>

  /// The collection of tags associated with the event.
  public let tags: [any Taggable]

  /// The measured execution duration of the function, when timing is enabled.
  /// `nil` when `@Log(measure: false)` suppresses timing at compile time.
  public var duration: Duration?

  /// `true` when the function was explicitly annotated with `@Log(measure: true)`,
  /// allowing the formatter to show timing even when the global default is off.
  public var isMeasuredExplicitly: Bool

  public var description: String {
    """
    source: \(source.map { String(describing: $0) } ?? "nil")
    location: \(location)
    declaration: \(declaration)
    parameters: \(parameters)
    result: \(result)
    tags: \(tags)
    """
  }

  public var debugDescription: String {
    """
    level: \(String(describing: level))
    source: \(source.map { String(describing: $0) } ?? "nil")
    location: \(location)
    declaration: \(declaration)
    parameters: \(parameters)
    result: \(result)
    tags: \(tags)
    duration: \(duration.map { String(describing: $0) } ?? "nil")
    """
  }

  /// Initializes an instance that aggregates metadata captured at
  /// the time of function invocation.
  ///
  /// - Parameters:
  ///   - level: The logging level at which the event should be emitted.
  ///   - location: The source location where the function was invoked.
  ///   - declaration: The function signature of the invoked function.
  ///   - parameters: The set of parameters and their corresponding argument values.
  ///   - result: The result returned by the function.
  ///   - tags: A collection of tags to associate with the event.
  ///   - isMeasuredExplicitly: Whether timing was explicitly requested via `@Log(measure: true)`.
  public init(
    level: (any Levelable)? = nil,
    source: (any Sourceable)? = nil,
    location: String,
    declaration: String,
    parameters: [String: Any] = [:],
    result: Result<Any, any Error> = .success(()),
    tags: [any Taggable] = [],
    isMeasuredExplicitly: Bool = false
  ) {
    self.level = level
    self.source = source
    self.location = location
    self.declaration = declaration
    self.parameters = parameters
    self.result = result
    self.tags = tags
    self.duration = nil
    self.isMeasuredExplicitly = isMeasuredExplicitly
  }

  /// A copy of this event representing the function's start, with `.start` level
  /// and default void result. Used by `emitStart(event:)` on `AutoLogger`.
  public var asStartEvent: AutoLogEvent {
    AutoLogEvent(
      level: LogLevel.start,
      source: source,
      location: location,
      declaration: declaration,
      parameters: parameters,
      result: .success(()),
      tags: tags
    )
  }
}

// TODO: 23122K - Consider using swift-log as a fallback when not running on Apple platforms
/// A default `AutoLogger` implementation that
/// uses a ``Logger`` instance to log to the default subsystem.
public struct AutoLogLogger: AutoLogger {
  /// The logger instance used for logging.
  let logger: Logger
  let formatter: any AutoLogFormatter

  /// Logs captured event metadata to the default subsystem.
  ///
  /// The event's logging level is inherited from the function result unless explicitly specified:
  /// - ``OSLogType.info`` for successful function executions.
  /// - ``OSLogType.error`` for functions that throw errors.
  public func emit(event: AutoLogEvent) {
    let message = formatter.format(event: event)
    if let level = event.level as? OSLogType {
      self.logger.log(level: level, "\(message)")
    } else {
      self.logger.log(level: event.result.isSuccess ? .info : .error, "\(message)")
    }
  }

  // NOTE: @_spi(Experimental) intentionally removed — using it with @Logged(using:) in
  // Swift 6.2.4 triggers a compiler ICE (ConstraintWalker crash during ResolveMacroRequest).
  // Restore once rdar://FB17xxx / swift-front-end crash is fixed upstream.
  /// Creates a new instance of this type to serve as the default handler
  /// for emitted events.
  ///
  /// Unless a custom logger is explicitly specified, this instance handles
  /// events emitted from:
  /// - ``Log(using:)
  /// - ``Log(using:level:omit:tag:)``
  ///
  /// - Parameters:
  ///   - logger: Logger used to log captured metadata.
  ///   - formatter: Formatter used to produce the log message string.
  public init(
    logger: Logger = Logger(),
    formatter: any AutoLogFormatter = CompactFormatter()
  ) {
    self.logger = logger
    self.formatter = formatter
  }
}

extension AutoLogger {
  /// Emits a start event (🔵) for the given event, respecting the global
  /// `AutoLogSettingsStorage.emitStartEvents` flag.
  ///
  /// Called automatically by macro-generated code at function entry.
  public func emitStart(event: AutoLogEvent) {
    guard AutoLogSettingsStorage.emitStartEvents else { return }
    emit(event: event.asStartEvent)
  }
}

extension AutoLogger where Self == AutoLogLogger {
  /// A default logger instance. Logs to default subsystem.
  public static var logger: Self { AutoLogLogger() }
}

extension Logger: AutoLogger {
  // Uses event.description (verbose multi-line format) intentionally.
  // This conformance supports the @OSLog / @OSLogged macro path.
  // Formatter-based output is only available via AutoLogLogger.
  public func emit(event: AutoLogEvent) {
    if let level = event.level as? OSLogType {
      self.log(level: level, "\(String(describing: event))")
    } else {
      self.log(level: event.result.isSuccess ? .info : .error, "\(String(describing: event))")
    }
  }
}

extension Result {
  fileprivate var isSuccess: Bool {
    guard case .success = self
    else { return false }
    return true
  }
}
