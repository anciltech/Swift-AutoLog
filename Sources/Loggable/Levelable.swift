/// A protocol describing a type used to express the level of an event.
///
/// A type should confrom to this protocol if it represents logging level.
///
/// @Comment {
///   The most common way to express a logging level is by using an enumeration.
///   Therefore, the recommended way to conform to `Levelable` is by using one.
/// }
public protocol Levelable: __Trait {
  /// The type of the associated value used to represent a logging level.
  associatedtype RawValue

  /// Returns the logging level for the given value.
  ///
  /// - Parameter value: The value associated with the logging level.
  ///
  /// - Returns: An instance representing the corresponding logging level.
  static func level(_ value: RawValue) -> Self
}

extension String: Levelable {
  /// Returns the logging level represented by the given string literal.
  ///
  /// - Parameter value: A string representing the logging level.
  ///
  /// - Returns: The same string value passed as the parameter.
  public static func level(_ value: String) -> String {
    value
  }
}

extension Levelable where Self == StringLiteralType {}

/// Semantic log levels with emoji-mapped meanings.
///
/// Use with `@Log(level:)` to explicitly annotate a function's intent,
/// or rely on automatic assignment by the macro:
/// - `.start` is injected before the function body executes (🔵)
/// - `.success` / `.failure` are derived from the function result (🟢 / 🔴)
public enum LogLevel: Levelable, Sendable, Hashable {
  /// Function called and started executing. Injected automatically by the macro. 🔵
  case start
  /// Function completed successfully. 🟢
  case success
  /// Function threw or returned a failure. 🔴
  case failure
  /// A notable condition that is not an error. 🟡
  case warning
  /// A developer-authored inline note emitted during function execution. 🟣
  case update

  public static func level(_ value: LogLevel) -> LogLevel { value }

  /// Initialise from a string literal (e.g. `"warning"`, `"start"`).
  /// Unrecognised strings map to `.update`.
  public init(stringLiteral value: String) {
    switch value {
    case "start":   self = .start
    case "success": self = .success
    case "failure": self = .failure
    case "warning": self = .warning
    default:        self = .update
    }
  }

  public var emoji: String {
    switch self {
    case .start:   return "🔵"
    case .success: return "🟢"
    case .failure: return "🔴"
    case .warning: return "🟡"
    case .update:  return "🟣"
    }
  }
}
