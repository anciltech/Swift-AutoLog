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
  func emit(event: AutoLogEvent, configuration: AutoLogConfiguration)

  /// Returns whether a macro-generated wrapper should capture elapsed time for
  /// `event` under the entry-time runtime configuration.
  func shouldMeasureTiming(for event: AutoLogEvent, configuration: AutoLogConfiguration) -> Bool
}

public extension AutoLogger {
  func shouldMeasureTiming(for event: AutoLogEvent, configuration: AutoLogConfiguration) -> Bool {
    event.isMeasuredExplicitly || configuration.measureTimingDefault
  }
}

/// Structured metadata describing an early-exit path taken by a logged function.
public struct AutoLogEarlyExit: Sendable, Hashable, CustomStringConvertible {
  /// The structural branch kind that produced the early exit.
  public enum Kind: String, Sendable, Hashable {
    case `guard`
    case `if`
    case elseif
    case `else`
    case switchCase = "switch case"
    case switchDefault = "switch default"
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

/// Structured metadata describing a locally handled error inside a logged function.
public struct AutoLogHandledError: Sendable, Hashable, CustomStringConvertible {
  public static let defaultMessage = "caught and handled locally"

  /// Human-readable context for the handled catch site.
  public let message: String

  public init(message: String = Self.defaultMessage) {
    self.message = message
  }

  public var description: String {
    message
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

  /// Best-effort type name derived from the source location.
  public let inferredTypeName: String

  /// Best-effort source line derived from `location`.
  public let sourceLine: String

  /// A compact `TypeName:Line` location summary for interaction rows.
  public let shortLocation: String

  /// Best-effort function name derived from the declaration string.
  public let functionName: String

  /// `true` when the declaration includes an `async` effect specifier.
  public let hasAsyncEffect: Bool

  /// A set of arguments passed to a function, associated
  /// with their parameter labels.
  public var parameters: [String: Any] {
    didSet {
      parameterLabels = Self.orderedParameterLabels(from: parameters)
    }
  }

  /// Stable parameter label order used by formatters.
  ///
  /// Dictionaries do not promise iteration order, so this is captured once when
  /// the event is created and reused by formatter paths that need deterministic
  /// output.
  public private(set) var parameterLabels: [String]

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

  /// Marks this event as a handled-error site emitted from within a `catch` block.
  public var handledError: AutoLogHandledError?

  /// The number of locally handled errors observed while the enclosing function continued.
  public var handledErrorCount: Int

  public var description: String {
    """
    source: \(source.map { String(describing: $0) } ?? "nil")
    location: \(location)
    declaration: \(declaration)
    parameters: \(parameters)
    result: \(result)
    earlyExit: \(String(describing: earlyExit))
    branchDecisions: \(branchDecisions)
    handledError: \(String(describing: handledError))
    handledErrorCount: \(handledErrorCount)
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
    handledError: \(String(describing: handledError))
    handledErrorCount: \(handledErrorCount)
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
    self.inferredTypeName = Self.extractTypeName(from: location)
    self.sourceLine = Self.extractLine(from: location)
    self.shortLocation = Self.shortLocation(from: location)
    self.functionName = Self.extractFunctionName(from: declaration)
    self.hasAsyncEffect = Self.hasAsyncEffect(in: declaration)
    self.parameters = parameters
    self.parameterLabels = Self.orderedParameterLabels(from: parameters)
    self.result = result
    self.tags = tags
    if tags.isEmpty {
      self.routes = []
      self.visibleTags = []
    } else if tags.count == 1, let tag = tags.first {
      if let route = tag as? AutoLogRoute {
        self.routes = [route]
        self.visibleTags = []
      } else {
        self.routes = []
        self.visibleTags = [tag]
      }
    } else {
      var routes = Set<AutoLogRoute>()
      var visibleTags: [any Taggable] = []
      visibleTags.reserveCapacity(tags.count)

      for tag in tags {
        if let route = tag as? AutoLogRoute {
          routes.insert(route)
        } else {
          visibleTags.append(tag)
        }
      }

      self.routes = routes
      self.visibleTags = visibleTags
    }
    self.deduplicateWithin = deduplicateWithin
    self.omissionRules = omissionRules
    self.duration = nil
    self.isMeasuredExplicitly = isMeasuredExplicitly
    self.executionContext = executionContext
    self.earlyExit = nil
    self.branchDecisions = []
    self.errorContext = []
    self.handledError = nil
    self.handledErrorCount = 0
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

  public mutating func recordHandledError(
    message: String = AutoLogHandledError.defaultMessage
  ) {
    _ = message
    handledErrorCount += 1
  }

  public func asHandledErrorEvent(
    _ error: (any Error)? = nil,
    location: String,
    message: String = AutoLogHandledError.defaultMessage
  ) -> AutoLogEvent {
    var event = AutoLogEvent(
      level: LogLevel.warning,
      source: source,
      location: location,
      declaration: declaration,
      parameters: parameters,
      result: error.map { .failure($0) } ?? .success(()),
      tags: tags,
      deduplicateWithin: deduplicateWithin,
      omissionRules: omissionRules
    )
    event.handledError = AutoLogHandledError(message: message)
    event.handledErrorCount = 1
    return event
  }

  public func withoutErrorContext() -> Self {
    var copy = self
    copy.errorContext = []
    return copy
  }

  private static func extractTypeName(from location: String) -> String {
    let filenameStart = location.lastIndex(of: "/").map { location.index(after: $0) } ?? location.startIndex
    let filenameWithSuffix = location[filenameStart...]
    let filenameEnd = filenameWithSuffix.firstIndex(of: ":") ?? filenameWithSuffix.endIndex
    var filename = filenameWithSuffix[..<filenameEnd]

    if filename.hasSuffix(".swift") {
      filename = filename.dropLast(6)
    }

    return filename.isEmpty ? "Unknown" : String(filename)
  }

  private static func extractLine(from location: String) -> String {
    let parts = location.split(separator: ":", maxSplits: 3, omittingEmptySubsequences: false)
    let candidates = parts.dropFirst().prefix(2)
    return candidates.first(where: { Int($0) != nil }).map(String.init) ?? "?"
  }

  private static func shortLocation(from location: String) -> String {
    let segments = location.split(separator: ":")
    let file = segments.first.map { String($0.split(separator: "/").last ?? Substring($0)) } ?? location
    let stem = file.replacingOccurrences(of: ".swift", with: "")
    let line = segments.dropFirst().first.map(String.init) ?? "?"
    return "\(stem):\(line)"
  }

  private static func extractFunctionName(from declaration: String) -> String {
    let start = declaration.range(of: "func ")?.upperBound ?? declaration.startIndex
    let suffix = declaration[start...]
    let end = suffix.firstIndex(where: { $0 == "<" || $0 == "(" }) ?? suffix.endIndex
    return String(suffix[..<end])
  }

  private static func hasAsyncEffect(in declaration: String) -> Bool {
    guard let range = declaration.range(of: "async") else { return false }

    let hasValidLeadingBoundary =
      range.lowerBound == declaration.startIndex ||
      declaration[declaration.index(before: range.lowerBound)].isWhitespace
    let hasValidTrailingBoundary =
      range.upperBound == declaration.endIndex ||
      declaration[range.upperBound].isWhitespace ||
      declaration[range.upperBound] == "-" ||
      declaration[range.upperBound] == "{"

    return hasValidLeadingBoundary && hasValidTrailingBoundary
  }

  private static func orderedParameterLabels(from parameters: [String: Any]) -> [String] {
    switch parameters.count {
    case 0:
      return []
    case 1:
      return parameters.first.map { [$0.key] } ?? []
    default:
      return parameters.keys.sorted()
    }
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

  private struct ResolvedOutputs {
    let matchedOutputs: [AutoLogOutput]
    let preferredContextOutput: AutoLogOutput
    let preferredConsoleOutput: AutoLogOutput?
    let snapshotCapacity: Int
  }

  private struct FailureContextSnapshot {
    let entries: [AutoLogErrorContextEntry]
  }

  private final class Storage: @unchecked Sendable {
    let state = AutoLogLock(State())
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
    let outputs = resolveOutputs(for: event, configuration: configuration)
    let preferredContextConfiguration = configuration.applying(
      output: outputs.preferredContextOutput
    )
    let failureContextSnapshot = makeFailureContextSnapshot(
      for: event,
      outputs: outputs.matchedOutputs
    )
    var snapshot: AutoLogErrorContextEntry?

    for output in outputs.matchedOutputs where output.route == .console {
      let outputConfiguration = if output == outputs.preferredContextOutput {
        preferredContextConfiguration
      } else {
        configuration.applying(output: output)
      }
      let enrichedEvent = enrichFailureContextIfNeeded(
        for: event,
        snapshot: failureContextSnapshot,
        contextLimit: output.errorContextLimit,
        triggerLimit: output.failureContextTriggerLimit
      )
      let message = formatter.format(event: enrichedEvent, configuration: outputConfiguration)
      if snapshot == nil, output == outputs.preferredConsoleOutput {
        snapshot = makeContextEntry(from: message, event: event)
      }
      if let level = enrichedEvent.level as? OSLogType {
        self.logger.log(level: level, "\(message)")
      } else {
        self.logger.log(level: enrichedEvent.result.isSuccess ? .info : .error, "\(message)")
      }
    }

    if snapshot == nil {
      snapshot = makeContextEntry(for: event, configuration: preferredContextConfiguration)
    }

    for output in outputs.matchedOutputs where output.route != .console {
      let outputConfiguration = configuration.applying(output: output)
      let enrichedEvent = enrichFailureContextIfNeeded(
        for: event,
        snapshot: failureContextSnapshot,
        contextLimit: output.errorContextLimit,
        triggerLimit: output.failureContextTriggerLimit
      )
      for sink in sinks where sink.route == output.route {
        sink.emit(event: enrichedEvent, configuration: outputConfiguration)
      }
    }

    if let snapshot {
      record(snapshot, capacity: outputs.snapshotCapacity)
    }
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

  private func makeFailureContextSnapshot(
    for event: AutoLogEvent,
    outputs: [AutoLogOutput]
  ) -> FailureContextSnapshot? {
    guard case .failure = event.result else { return nil }
    guard outputs.contains(where: { $0.errorContextLimit > 0 }) else { return nil }

    return storage.state.withLock { state in
      FailureContextSnapshot(entries: state.recentEntries)
    }
  }

  private func enrichFailureContextIfNeeded(
    for event: AutoLogEvent,
    snapshot: FailureContextSnapshot?,
    contextLimit: Int,
    triggerLimit: Int
  ) -> AutoLogEvent {
    guard case .failure = event.result,
          contextLimit > 0,
          let snapshot
    else { return event }

    var enriched = event
    let scopedEntries = recentEntriesWithinTriggerLimit(
      snapshot.entries,
      triggerLimit: triggerLimit
    )
    enriched.errorContext = Array(scopedEntries.suffix(contextLimit))
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
    return makeContextEntry(from: message, event: event)
  }

  private func makeContextEntry(
    from message: String,
    event: AutoLogEvent
  ) -> AutoLogErrorContextEntry {
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

  private func resolveOutputs(
    for event: AutoLogEvent,
    configuration: AutoLogConfiguration
  ) -> ResolvedOutputs {
    let effectiveOutputs = configuration.effectiveOutputs
    var matchedOutputs: [AutoLogOutput] = []
    matchedOutputs.reserveCapacity(effectiveOutputs.count)
    var preferredConsoleOutput: AutoLogOutput?
    var maxOutputErrorContextLimit = 0

    for output in effectiveOutputs {
      maxOutputErrorContextLimit = max(maxOutputErrorContextLimit, output.errorContextLimit)

      guard output.matches(event) else { continue }
      matchedOutputs.append(output)

      if preferredConsoleOutput == nil, output.route == .console {
        preferredConsoleOutput = output
      }
    }

    return ResolvedOutputs(
      matchedOutputs: matchedOutputs,
      preferredContextOutput: preferredConsoleOutput ?? effectiveOutputs.first ?? .default,
      preferredConsoleOutput: preferredConsoleOutput,
      snapshotCapacity: max(errorContextLimit, maxOutputErrorContextLimit, 5)
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

  /// Emits an event using the logger configuration and deduplicator captured at function entry.
  public func emitIfEnabled(
    event: AutoLogEvent,
    runtime: AutoLogRuntime
  ) {
    emitIfEnabled(
      event: event,
      configuration: runtime.configuration,
      deduplicator: runtime.deduplicator
    )
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

  /// Emits a start event using the logger configuration and deduplicator captured at function entry.
  public func emitStart(
    event: AutoLogEvent,
    runtime: AutoLogRuntime
  ) {
    emitStart(
      event: event,
      configuration: runtime.configuration,
      deduplicator: runtime.deduplicator
    )
  }

  /// Returns whether a macro-generated wrapper should capture elapsed time for
  /// `event` under the runtime captured at function entry.
  public func shouldMeasureTiming(for event: AutoLogEvent, runtime: AutoLogRuntime) -> Bool {
    shouldMeasureTiming(for: event, configuration: runtime.configuration)
  }

  /// Emits a warning-level handled-error event derived from a parent function event.
  ///
  /// This preserves the real caught error at the `catch` site while still honoring
  /// omission rules and duplicate suppression through ``emitIfEnabled(event:configuration:deduplicator:)``.
  public func emitHandledErrorIfEnabled(
    error: (any Error)? = nil,
    from parentEvent: AutoLogEvent,
    runtime: AutoLogRuntime,
    fileID: String = #fileID,
    line: Int = #line,
    column: Int = #column
  ) {
    emitIfEnabled(
      event: parentEvent.asHandledErrorEvent(
        error,
        location: "\(fileID):\(line):\(column)"
      ),
      configuration: runtime.configuration,
      deduplicator: runtime.deduplicator
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
