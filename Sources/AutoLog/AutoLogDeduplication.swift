/// A time window used to suppress repeated identical log events.
public struct AutoLogDeduplication: Sendable, Hashable, Codable {
  /// The suppression window in milliseconds.
  public let milliseconds: Int64

  public init(milliseconds: Int64) {
    self.milliseconds = milliseconds
  }

  /// Creates a suppression window from whole milliseconds.
  public static func milliseconds(_ value: Int64) -> Self {
    Self(milliseconds: value)
  }

  /// Creates a suppression window from fractional seconds.
  public static func seconds(_ value: Double) -> Self {
    Self(milliseconds: Int64((value * 1_000).rounded()))
  }

  fileprivate var duration: Duration {
    .seconds(Double(milliseconds) / 1_000)
  }
}

struct AutoLogDeduplicationState: Sendable {
  var lastEmissionByFingerprint: [String: ContinuousClock.Instant] = [:]
  var omissionCountByFingerprint: [String: Int] = [:]

  mutating func shouldEmit(
    fingerprint: String,
    within window: Duration,
    now: ContinuousClock.Instant
  ) -> Bool {
    prune(now: now)

    if let lastEmission = lastEmissionByFingerprint[fingerprint],
       now - lastEmission < window {
      return false
    }

    lastEmissionByFingerprint[fingerprint] = now
    return true
  }

  mutating func shouldEmitForOmissionRule(
    fingerprint: String,
    upToCount: Int
  ) -> Bool {
    let count = (omissionCountByFingerprint[fingerprint] ?? 0) + 1
    omissionCountByFingerprint[fingerprint] = count
    return count > upToCount
  }

  mutating func prune(now: ContinuousClock.Instant) {
    guard lastEmissionByFingerprint.count > 256 else { return }

    let retentionWindow = Duration.seconds(300)
    lastEmissionByFingerprint = lastEmissionByFingerprint.filter { _, instant in
      now - instant < retentionWindow
    }
  }
}

/// Suppresses repeated identical events inside a runtime snapshot.
public final class AutoLogDeduplicator: @unchecked Sendable {
  private let state: AutoLogLock<AutoLogDeduplicationState>

  public init() {
    self.state = AutoLogLock(AutoLogDeduplicationState())
  }

  public func shouldEmit(
    event: AutoLogEvent,
    configuration: AutoLogConfiguration,
    now: ContinuousClock.Instant = .now
  ) -> Bool {
    if let omissionDecision = omissionDecision(for: event) {
      switch omissionDecision {
      case .omitAlways:
        return false

      case .omitUpToCount(let fingerprint, let upToCount):
        let shouldEmit = state.withLock {
          $0.shouldEmitForOmissionRule(
            fingerprint: fingerprint,
            upToCount: upToCount
          )
        }

        guard shouldEmit else { return false }
      }
    }

    let effectiveWindow = event.deduplicateWithin ?? configuration.deduplicateWithin

    guard let effectiveWindow, effectiveWindow.milliseconds > 0 else {
      return true
    }

    let fingerprint = event.deduplicationFingerprint
    return state.withLock {
      $0.shouldEmit(
        fingerprint: fingerprint,
        within: effectiveWindow.duration,
        now: now
      )
    }
  }

  private func omissionDecision(for event: AutoLogEvent) -> AutoLogOmissionDecision? {
    for rule in event.omissionRules {
      guard let fingerprint = event.omissionFingerprint(for: rule) else { continue }

      if let upToCount = rule.upToCount {
        return .omitUpToCount(fingerprint: fingerprint, upToCount: upToCount)
      }

      return .omitAlways
    }

    return nil
  }
}

extension AutoLogEvent {
  fileprivate func omissionFingerprint(for rule: AutoLogOmissionRule) -> String? {
    switch rule.scope {
    case .result:
      guard case .success(let value) = result else { return nil }
      let summary = AutoLogComparison.summary(for: value)
      guard AutoLogComparison.matches(all: rule.tokens, in: summary) else { return nil }
      return [location, declaration, "result", summary, rule.tokens.joined(separator: "|")]
        .joined(separator: "|")

    case .error:
      guard case .failure(let error) = result else { return nil }
      let summary = AutoLogComparison.errorSummary(error)
      guard AutoLogComparison.matches(all: rule.tokens, in: summary) else { return nil }
      return [location, declaration, "error", summary, rule.tokens.joined(separator: "|")]
        .joined(separator: "|")
    }
  }

  fileprivate var deduplicationFingerprint: String {
    [
      location,
      declaration,
      level.map { String(describing: $0) } ?? "nil",
      source.map(AutoLogComparison.summary(for:)) ?? "nil",
      parameters
        .sorted { $0.key < $1.key }
        .map { "\($0.key)=\(AutoLogComparison.summary(for: $0.value))" }
        .joined(separator: "&"),
      resultSummary,
      tags.map { String(describing: $0) }.joined(separator: ","),
      earlyExit.map { String(describing: $0) } ?? "nil",
      branchDecisions.map { String(describing: $0) }.joined(separator: ","),
    ]
      .joined(separator: "|")
  }

  private var resultSummary: String {
    switch result {
    case .success(let value):
      return "success:\(AutoLogComparison.summary(for: value))"

    case .failure(let error):
      return "failure:\(AutoLogComparison.errorSummary(error))"
    }
  }
}

private enum AutoLogOmissionDecision {
  case omitAlways
  case omitUpToCount(fingerprint: String, upToCount: Int)
}
