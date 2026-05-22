/// Compile-time event paths that an AutoLog macro should generate.
///
/// Use these values with `@AutoLog(emit:)` or `@Log(emit:)` when a call site
/// should never compile some logging paths into the binary.
public struct AutoLogEmission: RawRepresentable, ExpressibleByStringLiteral, Sendable, Codable, Hashable {
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

/// Build-time emission policy derived from an ``AutoLogConfiguration``.
///
/// This type describes the maximum event paths that macro expansion should
/// generate. Runtime configuration can still filter events inside that ceiling,
/// but it cannot reintroduce paths that were not generated at build time.
public struct AutoLogBuildConfiguration: Sendable, Codable, Equatable {
  /// Event paths that macro expansion may generate.
  public var emissions: Set<AutoLogEmission>

  public init(emissions: Set<AutoLogEmission> = Self.defaultEmissions) {
    self.emissions = emissions
  }

  /// The default macro ceiling: start, success, thrown failure, and handled-error warning paths.
  public static let defaultEmissions: Set<AutoLogEmission> = [
    .starts,
    .successes,
    .failures,
    .warnings,
  ]

  public static let `default` = AutoLogBuildConfiguration()

  /// Emissions in a stable order suitable for generating source.
  public var orderedEmissions: [AutoLogEmission] {
    let preferredOrder: [AutoLogEmission] = [
      .starts,
      .successes,
      .failures,
      .warnings,
      .completions,
      .all,
    ]
    let preferred = preferredOrder.filter { emissions.contains($0) }
    let remaining = emissions
      .filter { !preferredOrder.contains($0) }
      .sorted { $0.rawValue < $1.rawValue }

    return preferred + remaining
  }

  /// A deterministic typed `emit:` argument such as `[.failures, .warnings]`.
  ///
  /// This is `nil` when no generated function event paths are enabled. A build
  /// tool can treat that as a signal to omit instrumentation rather than
  /// generating `emit: []`.
  public var macroEmitArgument: String? {
    guard !orderedEmissions.isEmpty else { return nil }
    return "[\(orderedEmissions.map { ".\($0.rawValue)" }.joined(separator: ", "))]"
  }
}
