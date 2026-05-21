/// Compile-time event paths that an AutoLog macro should generate.
///
/// Use these values with `@AutoLog(emit:)` or `@Log(emit:)` when a call site
/// should never compile some logging paths into the binary.
public struct AutoLogEmission: RawRepresentable, ExpressibleByStringLiteral, Sendable, Hashable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }

  public init(stringLiteral value: String) {
    self.rawValue = value
  }

  /// Generate all event paths. This is the default `@AutoLog` behavior.
  public static let all = AutoLogEmission("all")

  /// Generate successful and thrown completion paths, but no start path.
  public static let completions = AutoLogEmission("completions")

  /// Singular alias for ``completions``.
  public static let completion = completions

  /// Generate start rows.
  public static let starts = AutoLogEmission("starts")

  /// Singular alias for ``starts``.
  public static let start = starts

  /// Generate successful completion rows.
  public static let successes = AutoLogEmission("successes")

  /// Singular alias for ``successes``.
  public static let success = successes

  /// Generate thrown failure rows.
  public static let failures = AutoLogEmission("failures")

  /// Singular alias for ``failures``.
  public static let failure = failures

  /// Alias for ``failures``.
  public static let errors = failures

  /// Alias for ``failures``.
  public static let error = failures

  /// Generate locally handled catch-site warning rows.
  public static let warnings = AutoLogEmission("warnings")

  /// Singular alias for ``warnings``.
  public static let warning = warnings
}
