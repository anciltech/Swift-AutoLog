import Synchronization

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
  private let state: Mutex<AutoLogDeduplicationState>

  public init() {
    self.state = Mutex(AutoLogDeduplicationState())
  }

  public func shouldEmit(
    event: AutoLogEvent,
    configuration: AutoLogConfiguration,
    now: ContinuousClock.Instant = .now
  ) -> Bool {
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
}

extension AutoLogEvent {
  fileprivate var deduplicationFingerprint: String {
    [
      location,
      declaration,
      level.map { String(describing: $0) } ?? "nil",
      source.map(deduplicationSummary(for:)) ?? "nil",
      parameters
        .sorted { $0.key < $1.key }
        .map { "\($0.key)=\(deduplicationSummary(for: $0.value))" }
        .joined(separator: "&"),
      resultSummary,
      tags.map { String(describing: $0) }.joined(separator: ","),
      earlyExit.map { String(describing: $0) } ?? "nil",
    ]
      .joined(separator: "|")
  }

  private var resultSummary: String {
    switch result {
    case .success(let value):
      return "success:\(deduplicationSummary(for: value))"

    case .failure(let error):
      return "failure:\(type(of: error)):\(String(describing: error))"
    }
  }

  private func deduplicationSummary(for value: Any) -> String {
    if let type = value as? Any.Type {
      return String(reflecting: type)
    }

    return String(describing: value)
  }
}
