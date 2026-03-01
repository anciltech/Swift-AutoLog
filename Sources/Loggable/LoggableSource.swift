/// Manages the current interaction source via TaskLocal and emits
/// standalone interaction events when sources are activated.
public enum LoggableSource {
    /// The current interaction source, automatically propagated
    /// through structured concurrency (async/await, TaskGroup).
    @TaskLocal public static var current: (any Sourceable)?

    /// The logger used to emit standalone interaction events.
    /// Defaults to `LoggableLogger()`. Set this to customize
    /// where interaction events are logged.
    public static nonisolated(unsafe) var logger: any Loggable = LoggableLogger()

    /// Emits a standalone interaction event and runs the operation
    /// with the source set on the TaskLocal.
    ///
    /// All `@Logged` functions called within the operation will
    /// automatically see this source on `LoggableSource.current`.
    @discardableResult
    public static func run<T>(
        _ source: any Sourceable,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        operation: () throws -> T
    ) rethrows -> T {
        logger.emit(event: LoggableEvent(
            source: source,
            location: "\(fileID):\(line):\(column)",
            declaration: source.description
        ))
        return try $current.withValue(source) {
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
        logger.emit(event: LoggableEvent(
            source: source,
            location: "\(fileID):\(line):\(column)",
            declaration: source.description
        ))
        return try await $current.withValue(source) {
            try await operation()
        }
    }
}
