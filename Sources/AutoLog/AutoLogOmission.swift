/// Conditional omission rules generated from `@Omit(...)`.
public struct AutoLogOmissionRule: Sendable, Hashable, Codable, CustomStringConvertible {
  public enum Scope: String, Sendable, Hashable, Codable {
    case result
    case error
  }

  public let scope: Scope
  public let tokens: [String]
  public let upToCount: Int?

  public init(
    scope: Scope,
    tokens: [String] = [],
    upToCount: Int? = nil
  ) {
    self.scope = scope
    self.tokens = tokens
    self.upToCount = upToCount.map { max(0, $0) }
  }

  public var description: String {
    "scope=\(scope.rawValue) tokens=\(tokens) upToCount=\(String(describing: upToCount))"
  }
}
