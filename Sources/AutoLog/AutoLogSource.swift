import Foundation
import Synchronization

/// A `Sourceable` wrapper that pairs an interaction source with the call-site
/// location where it was activated. Stored in `AutoLogSource.current` so that
/// downstream `@AutoLog` function events can include the attribution line
/// (`↖ 👆🏼 Run [AsyncExamplesView:42]`).
///
/// `SourceContext` conforms to `Sourceable` by delegating all protocol
/// requirements to the wrapped source, so existing code reading
/// `AutoLogSource.current?.emoji` / `.label` continues to work unchanged.
public struct SourceContext: Sourceable, Sendable {
  private static let flowMarkers = [
    "🧵",
    "🧶",
    "🎯",
    "🚀",
    "🌈",
    "🔥",
    "⚡️",
    "🫧",
    "🛰️",
    "🎲"
  ]

  /// The underlying interaction source (e.g., `InteractionSource.button("Run")`).
  public let source: any Sourceable
  /// The call-site location in `fileID:line:column` format.
  public let location: String
  /// A short flow identifier shared by the interaction event and downstream work.
  public let interactionID: String
  /// A visual marker paired with the interaction ID to help separate overlapping flows.
  public let flowMarker: String

  public init(
    source: any Sourceable,
    location: String,
    interactionID: String,
    flowMarker: String? = nil
  ) {
    self.source = source
    self.location = location
    self.interactionID = interactionID
    self.flowMarker = flowMarker ?? SourceContext.pickFlowMarker(for: interactionID)
  }

  public init(source: any Sourceable, location: String) {
    self.init(
      source: source,
      location: location,
      interactionID: SourceContext.makeInteractionID()
    )
  }

  public var emoji: String       { source.emoji }
  public var label: String?      { source.label }
  public var description: String { source.description }
  public var traceBadge: String  { "\(flowMarker)\(interactionID)" }

  private static func makeInteractionID() -> String {
    UUID().uuidString
      .replacingOccurrences(of: "-", with: "")
      .prefix(6)
      .uppercased()
  }

  private static func pickFlowMarker(for interactionID: String) -> String {
    let scalarSum = interactionID.unicodeScalars.reduce(0) { partialResult, scalar in
      partialResult + Int(scalar.value)
    }
    return flowMarkers[scalarSum % flowMarkers.count]
  }
}

/// Manages the current interaction source via TaskLocal and emits
/// standalone interaction events when sources are activated.
public enum AutoLog {
  private static let runtimeState = Mutex(AutoLogRuntimeState())

  /// The current interaction source context, automatically propagated
  /// through structured concurrency (async/await, TaskGroup).
  ///
  /// The wrapped `SourceContext` carries both the source (emoji + label)
  /// and the call-site location, allowing function events to reference
  /// where the interaction originated.
  @TaskLocal public static var current: SourceContext?
  @TaskLocal private static var scopedRuntime: AutoLogRuntime?

  // MARK: - Runtime bootstrap and configuration

  /// Starts the process-local logger and live configuration store.
  ///
  /// If persisted configuration already exists in the store, it wins over
  /// `configuration` so companion-app changes survive relaunches.
  public static func start(
    logger: any AutoLogger = AutoLogLogger(),
    configuration: AutoLogConfiguration = .default,
    configurationStore: AutoLogConfigurationStore = .shared,
    refreshInterval: Duration = .seconds(2)
  ) {
    start(
      AutoLogBootstrap(
        logger: logger,
        configuration: configuration,
        configurationStore: configurationStore,
        refreshInterval: refreshInterval
      )
    )
  }

  /// Starts the process-local logger and live configuration store using an
  /// explicit bootstrap payload.
  ///
  /// If persisted configuration already exists in the store, it wins over
  /// `options.configuration` so companion-app changes survive relaunches.
  public static func start(_ options: AutoLogBootstrap) {
    runtimeState.withLock { $0.bootstrap(options) }
  }

  /// Compatibility alias for callers still using the older runtime setup name.
  public static func bootstrap(
    logger: any AutoLogger = AutoLogLogger(),
    configuration: AutoLogConfiguration = .default,
    configurationStore: AutoLogConfigurationStore = .shared,
    refreshInterval: Duration = .seconds(2)
  ) {
    start(
      logger: logger,
      configuration: configuration,
      configurationStore: configurationStore,
      refreshInterval: refreshInterval
    )
  }

  /// Compatibility alias for callers still using the older runtime setup name.
  public static func bootstrap(_ options: AutoLogBootstrap) {
    start(options)
  }

  /// Returns the current process-local runtime snapshot.
  ///
  /// The snapshot is stable for the duration of a logged function invocation,
  /// allowing the macro to use the same logger/configuration pair for start and
  /// completion events even if live configuration changes mid-flight.
  public static func runtimeSnapshot() -> AutoLogRuntime {
    if let scopedRuntime {
      return scopedRuntime
    }

    return runtimeState.withLock {
      $0.reloadConfigurationIfNeeded()
      return $0.runtime
    }
  }

  /// Persists and installs a new live configuration snapshot.
  public static func updateConfiguration(
    _ configuration: AutoLogConfiguration,
    persist: Bool = true
  ) {
    runtimeState.withLock { $0.updateConfiguration(configuration, persist: persist) }
  }

  /// Refreshes the in-process configuration from the shared store when the
  /// configured polling interval has elapsed.
  public static func reloadConfigurationIfNeeded() {
    guard scopedRuntime == nil else { return }
    runtimeState.withLock { $0.reloadConfigurationIfNeeded() }
  }

  /// Runs `operation` with a scoped runtime override that propagates through
  /// structured concurrency.
  @discardableResult
  public static func withRuntime<T>(
    _ runtime: AutoLogRuntime,
    operation: () throws -> T
  ) rethrows -> T {
    try $scopedRuntime.withValue(runtime) {
      try operation()
    }
  }

  /// Async variant of ``withRuntime(_:operation:)``.
  @discardableResult
  public static func withRuntime<T>(
    _ runtime: AutoLogRuntime,
    operation: () async throws -> T
  ) async rethrows -> T {
    try await $scopedRuntime.withValue(runtime) {
      try await operation()
    }
  }

  /// Runs `operation` with a scoped configuration override while preserving the
  /// current logger from the active runtime snapshot.
  @discardableResult
  public static func withConfiguration<T>(
    _ configuration: AutoLogConfiguration,
    operation: () throws -> T
  ) rethrows -> T {
    let baseRuntime = runtimeSnapshot()
    return try withRuntime(
      AutoLogRuntime(
        logger: baseRuntime.logger,
        configuration: configuration,
        deduplicator: baseRuntime.deduplicator
      ),
      operation: operation
    )
  }

  /// Async variant of ``withConfiguration(_:operation:)``.
  @discardableResult
  public static func withConfiguration<T>(
    _ configuration: AutoLogConfiguration,
    operation: () async throws -> T
  ) async rethrows -> T {
    let baseRuntime = runtimeSnapshot()
    return try await withRuntime(
      AutoLogRuntime(
        logger: baseRuntime.logger,
        configuration: configuration,
        deduplicator: baseRuntime.deduplicator
      ),
      operation: operation
    )
  }

  /// Runs `operation` with the supplied source context without emitting a new interaction event.
  @discardableResult
  public static func withSourceContext<T>(
    _ context: SourceContext?,
    operation: () throws -> T
  ) rethrows -> T {
    try $current.withValue(context) {
      try operation()
    }
  }

  /// Async variant of ``withSourceContext(_:operation:)``.
  @discardableResult
  public static func withSourceContext<T>(
    _ context: SourceContext?,
    operation: () async throws -> T
  ) async rethrows -> T {
    try await $current.withValue(context) {
      try await operation()
    }
  }

  // MARK: - Interaction source activation

  /// Emits a standalone interaction event and runs the operation
  /// with the source set on the TaskLocal.
  ///
  /// All `@AutoLog` functions called within the operation will
  /// automatically see this source on `AutoLogSource.current`.
  @discardableResult
  public static func run<T>(
    _ source: any Sourceable,
    fileID: String = #fileID,
    line: Int = #line,
    column: Int = #column,
    operation: () throws -> T
  ) rethrows -> T {
    let runtime = runtimeSnapshot()
    let locationString = "\(fileID):\(line):\(column)"
    let context = SourceContext(source: source, location: locationString)
    runtime.logger.emitIfEnabled(
      event: AutoLogEvent(
        source: context,
        location: locationString,
        declaration: source.description
      ),
      configuration: runtime.configuration,
      deduplicator: runtime.deduplicator
    )
    return try $current.withValue(context) {
      try operation()
    }
  }

  /// Async variant of ``run(_:fileID:line:column:operation:)``.
  @discardableResult
  public static func run<T>(
    _ source: any Sourceable,
    fileID: String = #fileID,
    line: Int = #line,
    column: Int = #column,
    operation: () async throws -> T
  ) async rethrows -> T {
    let runtime = runtimeSnapshot()
    let locationString = "\(fileID):\(line):\(column)"
    let context = SourceContext(source: source, location: locationString)
    runtime.logger.emitIfEnabled(
      event: AutoLogEvent(
        source: context,
        location: locationString,
        declaration: source.description
      ),
      configuration: runtime.configuration,
      deduplicator: runtime.deduplicator
    )
    return try await $current.withValue(context) {
      try await operation()
    }
  }

  // MARK: - Child task logging

  /// Emits a start/completion pair around arbitrary async work.
  ///
  /// This is useful for `Task { ... }`, `withTaskGroup`, or other child-task
  /// closures that cannot be directly annotated with `@Log` but should still
  /// appear as separate traced operations.
  ///
  /// The current `AutoLogSource.current` TaskLocal is preserved, so task-group
  /// children still inherit the interaction badge that triggered the parent
  /// workflow.
  @discardableResult
  public static func logTask<T>(
    _ declaration: String,
    level: (any Levelable)? = nil,
    fileID: String = #fileID,
    line: Int = #line,
    column: Int = #column,
    operation: () async throws -> T
  ) async rethrows -> T {
    let runtime = runtimeSnapshot()
    let autoLogger: any AutoLogger = runtime.logger
    var event = AutoLogEvent(
      level: level,
      source: current,
      location: "\(fileID):\(line):\(column)",
      declaration: declaration,
      parameters: [:],
      tags: []
    )
    autoLogger.emitStart(
      event: event,
      configuration: runtime.configuration,
      deduplicator: runtime.deduplicator
    )
    let start = ContinuousClock.now

    do {
      let result = try await operation()
      event.result = .success(result)
      event.duration = ContinuousClock.now - start
      autoLogger.emitIfEnabled(
        event: event,
        configuration: runtime.configuration,
        deduplicator: runtime.deduplicator
      )
      return result
    } catch {
      event.result = .failure(error)
      event.duration = ContinuousClock.now - start
      autoLogger.emitIfEnabled(
        event: event,
        configuration: runtime.configuration,
        deduplicator: runtime.deduplicator
      )
      throw error
    }
  }

  // MARK: - Manual inline logging

  /// Emits a manual log entry with the given level and message.
  ///
  /// Use this inside any function to annotate significant state changes
  /// or developer notes without attaching them to a function boundary.
  ///
  /// ```swift
  /// AutoLogSource.emit(.update, "User changed avatar")
  /// // → 🟣  "User changed avatar"
  /// ```
  public static func emit(
    _ level: LogLevel = .update,
    _ message: String,
    fileID: String = #fileID,
    line: Int = #line
  ) {
    let runtime = runtimeSnapshot()
    runtime.logger.emitIfEnabled(
      event: AutoLogEvent(
        level: level,
        source: current,
        location: "\(fileID):\(line)",
        declaration: message,
        parameters: [:]
      ),
      configuration: runtime.configuration,
      deduplicator: runtime.deduplicator
    )
  }

  /// Emits a manual inline note using the default `.update` level.
  public static func manual(
    _ message: String,
    fileID: String = #fileID,
    line: Int = #line
  ) {
    emit(.update, message, fileID: fileID, line: line)
  }

  /// Emits a developer-authored inline note.
  public static func note(
    _ message: String,
    fileID: String = #fileID,
    line: Int = #line
  ) {
    manual(message, fileID: fileID, line: line)
  }

  /// Emits a manual update event.
  public static func update(
    _ message: String,
    fileID: String = #fileID,
    line: Int = #line
  ) {
    emit(.update, message, fileID: fileID, line: line)
  }

  /// Emits a manual warning event.
  public static func warning(
    _ message: String,
    fileID: String = #fileID,
    line: Int = #line
  ) {
    emit(.warning, message, fileID: fileID, line: line)
  }

  /// Emits a manual success event.
  public static func success(
    _ message: String,
    fileID: String = #fileID,
    line: Int = #line
  ) {
    emit(.success, message, fileID: fileID, line: line)
  }

  /// Emits a manual failure event.
  public static func failure(
    _ message: String,
    fileID: String = #fileID,
    line: Int = #line
  ) {
    emit(.failure, message, fileID: fileID, line: line)
  }

  /// Marks the enclosing branch as an intentional early-exit path in an instrumented `@Log` function.
  ///
  /// Use this immediately before `return`, `throw`, `break`, or `continue` when the
  /// control-flow decision is meaningful and you want to preserve its intent in the final event.
  ///
  /// ```swift
  /// @Log
  /// func loadCachedValue() -> Value? {
  ///   if let cached = cache.value {
  ///     AutoLog.earlyExit(.optimize, "cache hit")
  ///     return cached
  ///   }
  ///
  ///   return nil
  /// }
  /// ```
  ///
  /// The macro rewrites this call into structured `event.earlyExit` metadata and keeps the
  /// normal result, thrown error, and duration capture intact. Outside macro-instrumented
  /// contexts, this method is a no-op.
  ///
  /// - Parameters:
  ///   - intent: A domain hint such as `.optimize` or `.expected`. Defaults to `.unknown`.
  ///   - message: Optional freeform context to include with the early exit.
  public static func earlyExit(
    _ intent: AutoLogEarlyExit.Intent = .unknown,
    _ message: String? = nil
  ) {}
}

/// Backward-compatible alias for the previous API entry point name.
public typealias AutoLogSource = AutoLog
