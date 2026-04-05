import Foundation
import Synchronization

private struct UserDefaultsBox: @unchecked Sendable {
  var value: UserDefaults
}

/// Live-tunable logging behavior shared across app processes.
public struct AutoLogConfiguration: Sendable, Codable, Equatable {
  /// Whether the macro should emit a 🔵 start event before a function executes.
  public var emitStartEvents: Bool

  /// Whether `@AutoLog` functions should display timing by default.
  public var measureTimingDefault: Bool

  /// Suppresses repeated identical log entries within the supplied time window.
  /// `nil` disables global duplicate suppression.
  public var deduplicateWithin: AutoLogDeduplication?

  /// Restrict timing display to specific depth levels (e.g. `[2]` for ViewModel only).
  /// `nil` means show timing for all depths when enabled.
  public var measureTimingDepths: Set<Int>?

  /// The visual layout used by ``CompactFormatter`` when no formatter-local override exists.
  public var logFormat: LogFormat

  public init(
    emitStartEvents: Bool = true,
    measureTimingDefault: Bool = true,
    deduplicateWithin: AutoLogDeduplication? = nil,
    measureTimingDepths: Set<Int>? = nil,
    logFormat: LogFormat = .default
  ) {
    self.emitStartEvents = emitStartEvents
    self.measureTimingDefault = measureTimingDefault
    self.deduplicateWithin = deduplicateWithin
    self.measureTimingDepths = measureTimingDepths
    self.logFormat = logFormat
  }

  public static let `default` = AutoLogConfiguration()
}

/// A process-local runtime snapshot used by the logging hot path.
public struct AutoLogRuntime: Sendable {
  public let logger: any AutoLogger
  public let configuration: AutoLogConfiguration
  public let deduplicator: AutoLogDeduplicator

  public init(
    logger: any AutoLogger,
    configuration: AutoLogConfiguration,
    deduplicator: AutoLogDeduplicator = AutoLogDeduplicator()
  ) {
    self.logger = logger
    self.configuration = configuration
    self.deduplicator = deduplicator
  }
}

/// Bootstraps the process-local logging runtime.
public struct AutoLogBootstrap {
  public var logger: any AutoLogger
  public var configuration: AutoLogConfiguration
  public var configurationStore: AutoLogConfigurationStore
  public var refreshInterval: Duration

  public init(
    logger: any AutoLogger = AutoLogLogger(),
    configuration: AutoLogConfiguration = .default,
    configurationStore: AutoLogConfigurationStore = .shared,
    refreshInterval: Duration = .seconds(2)
  ) {
    self.logger = logger
    self.configuration = configuration
    self.configurationStore = configurationStore
    self.refreshInterval = refreshInterval
  }
}

/// Persists live configuration shared by the companion settings app and host apps.
public struct AutoLogConfigurationStore: @unchecked Sendable {
  public static let sharedSuiteName = "SwiftAutoLog.Configuration"

  private let userDefaultsBox: UserDefaultsBox
  public let configurationKey: String
  public let revisionKey: String

  public init(
    userDefaults: UserDefaults,
    configurationKey: String = "autolog.configuration",
    revisionKey: String = "autolog.configuration.revision"
  ) {
    self.userDefaultsBox = UserDefaultsBox(value: userDefaults)
    self.configurationKey = configurationKey
    self.revisionKey = revisionKey
  }

  public init(
    suiteName: String = AutoLogConfigurationStore.sharedSuiteName,
    configurationKey: String = "autolog.configuration",
    revisionKey: String = "autolog.configuration.revision"
  ) {
    self.init(
      userDefaults: UserDefaults(suiteName: suiteName) ?? .standard,
      configurationKey: configurationKey,
      revisionKey: revisionKey
    )
  }

  public static var shared: Self { AutoLogConfigurationStore() }

  public func loadConfiguration() -> AutoLogConfiguration? {
    guard
      let data = userDefaults.data(forKey: configurationKey),
      let configuration = try? JSONDecoder().decode(AutoLogConfiguration.self, from: data)
    else { return nil }

    return configuration
  }

  public func saveConfiguration(_ configuration: AutoLogConfiguration) {
    guard let data = try? JSONEncoder().encode(configuration) else { return }

    let nextRevision = loadRevision() + 1
    userDefaults.set(data, forKey: configurationKey)
    userDefaults.set(NSNumber(value: nextRevision), forKey: revisionKey)
  }

  public func loadRevision() -> UInt64 {
    (userDefaults.object(forKey: revisionKey) as? NSNumber)?.uint64Value ?? 0
  }

  private var userDefaults: UserDefaults { userDefaultsBox.value }
}

struct AutoLogRuntimeState {
  var runtime: AutoLogRuntime
  var configurationStore: AutoLogConfigurationStore
  var refreshInterval: Duration
  var lastRefresh: ContinuousClock.Instant?
  var lastSeenRevision: UInt64

  init(_ bootstrap: AutoLogBootstrap = AutoLogBootstrap()) {
    let persisted = bootstrap.configurationStore.loadConfiguration()
    let configuration = persisted ?? bootstrap.configuration
    self.runtime = AutoLogRuntime(
      logger: bootstrap.logger,
      configuration: configuration
    )
    self.configurationStore = bootstrap.configurationStore
    self.refreshInterval = bootstrap.refreshInterval
    self.lastRefresh = nil
    self.lastSeenRevision = bootstrap.configurationStore.loadRevision()
  }

  mutating func reloadConfigurationIfNeeded(now: ContinuousClock.Instant = .now) {
    if let lastRefresh, now - lastRefresh < refreshInterval {
      return
    }

    lastRefresh = now

    let revision = configurationStore.loadRevision()
    guard revision != lastSeenRevision else { return }

    lastSeenRevision = revision

    guard let configuration = configurationStore.loadConfiguration() else { return }

    runtime = AutoLogRuntime(
      logger: runtime.logger,
      configuration: configuration,
      deduplicator: runtime.deduplicator
    )
  }

  mutating func updateConfiguration(
    _ configuration: AutoLogConfiguration,
    persist: Bool
  ) {
    runtime = AutoLogRuntime(
      logger: runtime.logger,
      configuration: configuration,
      deduplicator: runtime.deduplicator
    )

    if persist {
      configurationStore.saveConfiguration(configuration)
      lastSeenRevision = configurationStore.loadRevision()
    }

    lastRefresh = .now
  }

  mutating func bootstrap(_ bootstrap: AutoLogBootstrap) {
    self = AutoLogRuntimeState(bootstrap)
  }
}

extension AutoLogger where Self == AutoLogLogger {
  public static var cleanArchitecture: Self {
    AutoLogLogger(formatter: CompactFormatter(profile: .cleanArchitecture))
  }

  public static var mvvm: Self {
    AutoLogLogger(formatter: CompactFormatter(profile: .mvvm))
  }
}
