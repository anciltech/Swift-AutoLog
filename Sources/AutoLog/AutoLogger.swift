#if canImport(OSLog)
@_exported public import OSLog
#endif

import Synchronization

/// A protocol that provides instances of conforming types with the ability to
/// handle emitted events.
public protocol AutoLogger: Sendable {
  /// Handle an emitted event.
  ///
  /// Events are currently emitted in the following cases:
  ///   - When the function completes successfully
  ///   - When the function throws an error.
  ///
  func emit(event: AutoLogEvent, configuration: AutoLogConfiguration)
}

/// Structured metadata describing an early-exit path taken by a logged function.
public struct AutoLogEarlyExit: Sendable, Hashable, CustomStringConvertible {
  /// The structural branch kind that produced the early exit.
  public enum Kind: String, Sendable, Hashable {
    case `guard`
    case `if`
    case elseif
    case `else`
  }

  /// A domain-level hint describing the intent behind the early exit.
  ///
  /// Intent is optional and does not affect whether the overall event is treated as a success
  /// or failure. That remains derived from the final `result`.
  public enum Intent: String, Sendable, Hashable {
    case unknown
    case optimize
    case expected
    case validation
    case cancellation
  }

  /// The control-flow branch that was taken.
  public let kind: Kind
  /// An optional intent provided by the author with `AutoLog.earlyExit(...)`.
  public let intent: Intent
  /// The branch condition captured by the macro when available.
  public let condition: String?
  /// Optional human-authored context describing the early exit.
  public let message: String?

  public init(
    kind: Kind,
    intent: Intent = .unknown,
    condition: String? = nil,
    message: String? = nil
  ) {
    self.kind = kind
    self.intent = intent
    self.condition = condition
    self.message = message
  }

  public var description: String {
    var components: [String] = ["\(kind.rawValue) early exit"]

    if intent != .unknown {
      components.append("intent=\(intent.rawValue)")
    }

    if let condition, !condition.isEmpty {
      components.append("condition=\(condition)")
    }

    if let message, !message.isEmpty {
      components.append("message=\(message)")
    }

    return components.joined(separator: " ")
  }
}

/// Structured metadata describing a conditional branch that executed within a logged function.
public struct AutoLogBranchDecision: Sendable, Hashable, CustomStringConvertible {
  /// The structural branch kind that executed.
  public let kind: AutoLogEarlyExit.Kind
  /// The branch condition captured by the macro when available.
  public let condition: String?

  public init(
    kind: AutoLogEarlyExit.Kind,
    condition: String? = nil
  ) {
    self.kind = kind
    self.condition = condition
  }

  public var description: String {
    var components: [String] = ["\(kind.rawValue) branch"]

    if let condition, !condition.isEmpty {
      components.append("condition=\(condition)")
    }

    return components.joined(separator: " ")
  }
}

/// A previously emitted log line retained as context for a later failure.
public struct AutoLogErrorContextEntry: Sendable, Hashable, CustomStringConvertible {
  /// A single-line summary of the earlier log entry.
  public let summary: String
  /// Marks interaction and start entries so failure context can keep the last N triggers.
  public let isTrigger: Bool

  public init(summary: String, isTrigger: Bool = false) {
    self.summary = summary
    self.isTrigger = isTrigger
  }

  public var description: String {
    summary
  }
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

  /// The sink routes declared for this event via ``Tag(_:)``.
  ///
  /// When empty, the event defaults to the built-in console sink.
  public let routes: Set<AutoLogRoute>

  /// User-facing tags after removing routing directives used by the logger.
  public let visibleTags: [any Taggable]

  /// The measured execution duration of the function, when timing is enabled.
  /// `nil` when `@Log(measure: false)` suppresses timing at compile time.
  public var duration: Duration?

  /// Execution-context metadata captured at the point the event is emitted.
  public var executionContext: AutoLogExecutionContext

  /// `true` when the function was explicitly annotated with `@Log(measure: true)`,
  /// allowing the formatter to show timing even when the global default is off.
  public var isMeasuredExplicitly: Bool

  /// A per-event override for duplicate suppression.
  ///
  /// When `nil`, the runtime falls back to ``AutoLogConfiguration/deduplicateWithin``.
  public let deduplicateWithin: AutoLogDeduplication?

  /// Conditional omission rules evaluated before duplicate suppression.
  public let omissionRules: [AutoLogOmissionRule]

  /// Describes an early-exit path taken within the function body, when known.
  ///
  /// This metadata is orthogonal to `result`. For example, a function may exit early from a
  /// `guard` branch and still finish with `.success(false)` or `.success(nil)`.
  public var earlyExit: AutoLogEarlyExit?

  /// The conditional branches that executed while the function continued normally.
  ///
  /// This keeps meaningful `if` / `else if` / `else` decisions visible even when they do not
  /// immediately `return` or `throw`.
  public var branchDecisions: [AutoLogBranchDecision]

  /// The most recent emitted log summaries that led up to a failure.
  ///
  /// `AutoLogLogger` fills this with a rolling trail of previous log lines immediately before
  /// formatting or forwarding an error event.
  public var errorContext: [AutoLogErrorContextEntry]

  public var description: String {
    """
    source: \(source.map { String(describing: $0) } ?? "nil")
    location: \(location)
    declaration: \(declaration)
    parameters: \(parameters)
    result: \(result)
    earlyExit: \(String(describing: earlyExit))
    branchDecisions: \(branchDecisions)
    errorContext: \(errorContext)
    tags: \(tags)
    routes: \(Array(routes).sorted { $0.rawValue < $1.rawValue })
    executionContext: \(executionContext)
    deduplicateWithin: \(String(describing: deduplicateWithin))
    omissionRules: \(omissionRules)
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
    earlyExit: \(String(describing: earlyExit))
    branchDecisions: \(branchDecisions)
    errorContext: \(errorContext)
    tags: \(tags)
    routes: \(Array(routes).sorted { $0.rawValue < $1.rawValue })
    duration: \(duration.map { String(describing: $0) } ?? "nil")
    executionContext: \(executionContext)
    deduplicateWithin: \(String(describing: deduplicateWithin))
    omissionRules: \(omissionRules)
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
  ///   - deduplicateWithin: A per-event duplicate suppression window override.
  ///   - omissionRules: Conditional omission rules evaluated before emission.
  ///   - isMeasuredExplicitly: Whether timing was explicitly requested via `@Log(measure: true)`.
  public init(
    level: (any Levelable)? = nil,
    source: (any Sourceable)? = nil,
    location: String,
    declaration: String,
    parameters: [String: Any] = [:],
    result: Result<Any, any Error> = .success(()),
    tags: [any Taggable] = [],
    deduplicateWithin: AutoLogDeduplication? = nil,
    omissionRules: [AutoLogOmissionRule] = [],
    isMeasuredExplicitly: Bool = false,
    executionContext: AutoLogExecutionContext = .capture()
  ) {
    self.level = level
    self.source = source
    self.location = location
    self.declaration = declaration
    self.parameters = parameters
    self.result = result
    self.tags = tags
    self.routes = Set(tags.compactMap { $0 as? AutoLogRoute })
    self.visibleTags = tags.filter { !($0 is AutoLogRoute) }
    self.deduplicateWithin = deduplicateWithin
    self.omissionRules = omissionRules
    self.duration = nil
    self.isMeasuredExplicitly = isMeasuredExplicitly
    self.executionContext = executionContext
    self.earlyExit = nil
    self.branchDecisions = []
    self.errorContext = []
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
      tags: tags,
      deduplicateWithin: deduplicateWithin,
      omissionRules: omissionRules,
      executionContext: executionContext
    )
  }

  public mutating func setEarlyExit(
    kind: AutoLogEarlyExit.Kind,
    intent: AutoLogEarlyExit.Intent = .unknown,
    condition: String? = nil,
    message: String? = nil
  ) {
    earlyExit = AutoLogEarlyExit(
      kind: kind,
      intent: intent,
      condition: condition,
      message: message
    )
  }

  public mutating func recordBranchDecision(
    kind: AutoLogEarlyExit.Kind,
    condition: String? = nil
  ) {
    branchDecisions.append(
      AutoLogBranchDecision(
        kind: kind,
        condition: condition
      )
    )
  }

  public func withoutErrorContext() -> Self {
    var copy = self
    copy.errorContext = []
    return copy
  }
}

// TODO: 23122K - Consider using swift-log as a fallback when not running on Apple platforms
public protocol AutoLogEventSink: Sendable {
  /// The route name this sink listens for.
  var route: AutoLogRoute { get }

  /// Handles an emitted event that matched `route`.
  func emit(event: AutoLogEvent, configuration: AutoLogConfiguration)
}

/// A default `AutoLogger` implementation that
/// uses a ``Logger`` instance to log to the default subsystem.
public struct AutoLogLogger: AutoLogger {
  private struct State: Sendable {
    var recentEntries: [AutoLogErrorContextEntry] = []
  }

  private final class Storage: @unchecked Sendable {
    let state = Mutex(State())
  }

  /// The logger instance used for logging.
  let logger: Logger
  let formatter: any AutoLogFormatter
  let sinks: [any AutoLogEventSink]
  let errorContextLimit: Int
  private let storage: Storage

  /// Logs captured event metadata to the default subsystem.
  ///
  /// The event's logging level is inherited from the function result unless explicitly specified:
  /// - ``OSLogType.info`` for successful function executions.
  /// - ``OSLogType.error`` for functions that throw errors.
  public func emit(event: AutoLogEvent, configuration: AutoLogConfiguration) {
    let outputs = configuration.effectiveOutputs.filter { $0.matches(event) }
    let preferredContextConfiguration = configuration.applying(
      output: outputs.first(where: { $0.route == .console }) ?? configuration.effectiveOutputs.first ?? .default
    )
    let snapshot = makeContextEntry(for: event, configuration: preferredContextConfiguration)

    for output in outputs where output.route == .console {
      let outputConfiguration = configuration.applying(output: output)
      let enrichedEvent = enrichFailureContextIfNeeded(
        for: event,
        contextLimit: output.errorContextLimit,
        triggerLimit: output.failureContextTriggerLimit
      )
      let message = formatter.format(event: enrichedEvent, configuration: outputConfiguration)
      if let level = enrichedEvent.level as? OSLogType {
        self.logger.log(level: level, "\(message)")
      } else {
        self.logger.log(level: enrichedEvent.result.isSuccess ? .info : .error, "\(message)")
      }
    }

    for output in outputs where output.route != .console {
      let outputConfiguration = configuration.applying(output: output)
      let enrichedEvent = enrichFailureContextIfNeeded(
        for: event,
        contextLimit: output.errorContextLimit,
        triggerLimit: output.failureContextTriggerLimit
      )
      for sink in sinks where sink.route == output.route {
        sink.emit(event: enrichedEvent, configuration: outputConfiguration)
      }
    }

    record(snapshot, capacity: max(errorContextLimit, configuration.maxErrorContextLimit))
  }

  // NOTE: @_spi(Experimental) intentionally removed — using it with @AutoLog(using:) in
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
    formatter: any AutoLogFormatter = CompactFormatter(),
    sinks: [any AutoLogEventSink] = [],
    errorContextLimit: Int = 5
  ) {
    self.logger = logger
    self.formatter = formatter
    self.sinks = sinks
    self.errorContextLimit = max(0, errorContextLimit)
    self.storage = Storage()
  }

  private func enrichFailureContextIfNeeded(
    for event: AutoLogEvent,
    contextLimit: Int,
    triggerLimit: Int
  ) -> AutoLogEvent {
    guard case .failure = event.result, contextLimit > 0 else { return event }

    var enriched = event
    enriched.errorContext = storage.state.withLock { state in
      let scopedEntries = recentEntriesWithinTriggerLimit(
        state.recentEntries,
        triggerLimit: triggerLimit
      )
      return Array(scopedEntries.suffix(contextLimit))
    }
    return enriched
  }

  private func makeContextEntry(
    for event: AutoLogEvent,
    configuration: AutoLogConfiguration
  ) -> AutoLogErrorContextEntry {
    let message = formatter.format(
      event: event.withoutErrorContext(),
      configuration: configuration
    )
    let summary = message
      .split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
      .first
      .map(String.init)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
      ?? ""
    return AutoLogErrorContextEntry(
      summary: summary,
      isTrigger: event.outputEventType == .interaction || event.outputEventType == .start
    )
  }

  private func recentEntriesWithinTriggerLimit(
    _ entries: [AutoLogErrorContextEntry],
    triggerLimit: Int
  ) -> [AutoLogErrorContextEntry] {
    guard triggerLimit > 0 else { return entries }

    let triggerIndexes = entries.indices.filter { entries[$0].isTrigger }
    guard triggerIndexes.count > triggerLimit else { return entries }

    let startIndex = triggerIndexes[triggerIndexes.count - triggerLimit]
    return Array(entries[startIndex...])
  }

  private func record(_ entry: AutoLogErrorContextEntry, capacity: Int) {
    guard capacity > 0 else { return }

    storage.state.withLock { state in
      state.recentEntries.append(entry)
      if state.recentEntries.count > capacity {
        state.recentEntries.removeFirst(state.recentEntries.count - capacity)
      }
    }
  }
}

extension AutoLogger {
  /// Emits an event only when it is not suppressed by deduplication settings.
  public func emitIfEnabled(
    event: AutoLogEvent,
    configuration: AutoLogConfiguration,
    deduplicator: AutoLogDeduplicator
  ) {
    var enrichedEvent = event
    enrichedEvent.executionContext = .capture()
    guard deduplicator.shouldEmit(event: enrichedEvent, configuration: configuration) else { return }
    emit(event: enrichedEvent, configuration: configuration)
  }

  /// Emits a start event (🔵) for the given event when enabled by configuration.
  ///
  /// Called automatically by macro-generated code at function entry.
  public func emitStart(
    event: AutoLogEvent,
    configuration: AutoLogConfiguration
  ) {
    guard configuration.emitStartEvents else { return }
    emit(event: event.asStartEvent, configuration: configuration)
  }

  /// Emits a start event while honoring the runtime's deduplication settings.
  public func emitStart(
    event: AutoLogEvent,
    configuration: AutoLogConfiguration,
    deduplicator: AutoLogDeduplicator
  ) {
    guard configuration.emitStartEvents else { return }
    emitIfEnabled(
      event: event.asStartEvent,
      configuration: configuration,
      deduplicator: deduplicator
    )
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
  public func emit(
    event: AutoLogEvent,
    configuration: AutoLogConfiguration
  ) {
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
