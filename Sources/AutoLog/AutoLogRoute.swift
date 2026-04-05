/// A routing tag that declares which sinks should receive an emitted event.
///
/// When no route tags are attached, events default to the built-in console sink.
/// When one or more routes are attached, only the declared routes receive the event.
public struct AutoLogRoute: Taggable, Sendable, Hashable, Codable, ExpressibleByStringLiteral, CustomStringConvertible {
  public let rawValue: String

  public init(_ rawValue: String) {
    self.rawValue = rawValue.lowercased()
  }

  public static func tag(_ value: String) -> Self {
    Self(value)
  }

  public init(stringLiteral value: StringLiteralType) {
    self.init(value)
  }

  public var description: String { rawValue }

  /// The built-in console sink used by ``AutoLogLogger``.
  public static let console = Self("console")

  /// A conventional route name for Splunk forwarding.
  public static let splunk = Self("splunk")

  /// A conventional route name for Firebase forwarding.
  public static let firebase = Self("firebase")
}

extension Taggable where Self == AutoLogRoute {
  public static var console: any Taggable { AutoLogRoute.console }
  public static var splunk: any Taggable { AutoLogRoute.splunk }
  public static var firebase: any Taggable { AutoLogRoute.firebase }

  /// Creates a custom routing tag for a backend name such as `"datadog"` or `"sentry"`.
  public static func route(_ value: String) -> any Taggable {
    AutoLogRoute(value)
  }
}

