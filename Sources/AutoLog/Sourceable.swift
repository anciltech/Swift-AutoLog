/// A protocol representing the source that triggered a logged interaction.
///
/// Conform to this protocol to define custom interaction sources.
/// The library provides ``InteractionSource`` with built-in cases
/// for common UI interactions.
public protocol Sourceable: Sendable, CustomStringConvertible {
    /// The emoji representing this source type.
    var emoji: String { get }
    /// An optional human-readable label identifying the specific control.
    var label: String? { get }
}

public extension Sourceable {
    /// Emits an interaction event for this source and runs the operation with
    /// the source propagated through ``AutoLog/current``.
    @discardableResult
    func log<T>(
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        operation: () throws -> T
    ) rethrows -> T {
        try AutoLog.run(
            self,
            fileID: fileID,
            line: line,
            column: column,
            operation: operation
        )
    }

    /// Async variant of ``log(fileID:line:column:operation:)`` that remains on
    /// the caller's actor.
    @discardableResult
    nonisolated(nonsending) func log<T>(
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        operation: () async throws -> T
    ) async rethrows -> T {
        try await AutoLog.run(
            self,
            fileID: fileID,
            line: line,
            column: column,
            operation: operation
        )
    }
}

/// Built-in interaction source types with source-specific emojis.
public enum AutoLogInteraction: Sourceable {
    case button(String?)
    case textField(String?)
    case keyboard(String?)
    case toggle(String?)
    case gesture(String?)
    case api(String?)
    case system(String?)
    case timer(String?)
    case unknown

    public var emoji: String {
        switch self {
        case .button:    "👆🏼"
        case .textField: "💬"
        case .keyboard:  "⌨️"
        case .toggle:    "🔀"
        case .gesture:   "🤌🏼"
        case .api:       "🌐"
        case .system:    "⚙️"
        case .timer:     "⏱️"
        case .unknown:   "❓"
        }
    }

    public var label: String? {
        switch self {
        case .button(let l),
             .textField(let l),
             .keyboard(let l),
             .toggle(let l),
             .gesture(let l),
             .api(let l),
             .system(let l),
             .timer(let l):
            l
        case .unknown:
            nil
        }
    }

    public var description: String {
        let caseName: String
        switch self {
        case .button:    caseName = "button"
        case .textField: caseName = "textField"
        case .keyboard:  caseName = "keyboard"
        case .toggle:    caseName = "toggle"
        case .gesture:   caseName = "gesture"
        case .api:       caseName = "api"
        case .system:    caseName = "system"
        case .timer:     caseName = "timer"
        case .unknown:   return "unknown"
        }
        if let label {
            return "\(caseName)(\"\(label)\")"
        }
        return caseName
    }
}

/// Backward-compatible alias for older code that still references
/// `InteractionSource.button(...)`.
public typealias InteractionSource = AutoLogInteraction
