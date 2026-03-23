/// A `Sourceable` wrapper that pairs an interaction source with the call-site
/// location where it was activated. Stored in `AutoLogSource.current` so that
/// downstream `@Logged` function events can include the attribution line
/// (`↖ 👆🏼 Run [AsyncExamplesView:42]`).
///
/// `SourceContext` conforms to `Sourceable` by delegating all protocol
/// requirements to the wrapped source, so existing code reading
/// `AutoLogSource.current?.emoji` / `.label` continues to work unchanged.
public struct SourceContext: Sourceable, Sendable {
  /// The underlying interaction source (e.g., `InteractionSource.button("Run")`).
  public let source: any Sourceable
  /// The call-site location in `fileID:line:column` format.
  public let location: String

  public init(source: any Sourceable, location: String) {
    self.source = source
    self.location = location
  }

  public var emoji: String       { source.emoji }
  public var label: String?      { source.label }
  public var description: String { source.description }
}

/// Manages the current interaction source via TaskLocal and emits
/// standalone interaction events when sources are activated.
public enum AutoLogSource {
  /// The current interaction source context, automatically propagated
  /// through structured concurrency (async/await, TaskGroup).
  ///
  /// The wrapped `SourceContext` carries both the source (emoji + label)
  /// and the call-site location, allowing function events to reference
  /// where the interaction originated.
  @TaskLocal public static var current: SourceContext?

  /// The logger used to emit standalone interaction events.
  /// Defaults to `AutoLogLogger()`. Set this to customize
  /// where interaction events are logged.
  ///
  /// - Important: Set this property during app initialization only,
  ///   before any concurrent calls to ``run(_:fileID:line:column:operation:)``.
  ///   Mutating it concurrently with `run()` calls is a data race.
  public static nonisolated(unsafe) var logger: any AutoLogger = AutoLogLogger()

  // MARK: - Interaction source activation

  /// Emits a standalone interaction event and runs the operation
  /// with the source set on the TaskLocal.
  ///
  /// All `@Logged` functions called within the operation will
  /// automatically see this source on `AutoLogSource.current`.
  @discardableResult
  public static func run<T>(
    _ source: any Sourceable,
    fileID: String = #fileID,
    line: Int = #line,
    column: Int = #column,
    operation: () throws -> T
  ) rethrows -> T {
    let locationString = "\(fileID):\(line):\(column)"
    logger.emit(event: AutoLogEvent(
      source: source,
      location: locationString,
      declaration: source.description
    ))
    return try $current.withValue(SourceContext(source: source, location: locationString)) {
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
    let locationString = "\(fileID):\(line):\(column)"
    logger.emit(event: AutoLogEvent(
      source: source,
      location: locationString,
      declaration: source.description
    ))
    return try await $current.withValue(SourceContext(source: source, location: locationString)) {
      try await operation()
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
    logger.emit(event: AutoLogEvent(
      level: level,
      source: current?.source,
      location: "\(fileID):\(line)",
      declaration: message,
      parameters: [:]
    ))
  }
}
