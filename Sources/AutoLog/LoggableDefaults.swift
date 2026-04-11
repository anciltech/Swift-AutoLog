import Foundation
import Synchronization

private struct UserDefaultsBox: @unchecked Sendable {
  var value: UserDefaults
}

public enum AutoLogOutputEventType: String, Sendable, Codable, CaseIterable, Hashable {
  case interaction
  case start
  case success
  case failure
}

public struct AutoLogOutput: Sendable, Codable, Equatable, Identifiable {
  public var id: String
  public var name: String
  public var route: AutoLogRoute
  public var isEnabled: Bool
  public var eventTypes: Set<AutoLogOutputEventType>
  public var typeNameFilters: [String]
  public var measureTiming: Bool
  public var timingDepths: Set<Int>?
  public var errorContextLimit: Int
  public var logFormat: LogFormat

  public init(
    id: String = UUID().uuidString,
    name: String,
    route: AutoLogRoute = .console,
    isEnabled: Bool = true,
    eventTypes: Set<AutoLogOutputEventType> = Set(AutoLogOutputEventType.allCases),
    typeNameFilters: [String] = [],
    measureTiming: Bool = true,
    timingDepths: Set<Int>? = nil,
    errorContextLimit: Int = 5,
    logFormat: LogFormat = .default
  ) {
    self.id = id
    self.name = name
    self.route = route
    self.isEnabled = isEnabled
    self.eventTypes = eventTypes
    self.typeNameFilters = typeNameFilters
    self.measureTiming = measureTiming
    self.timingDepths = timingDepths
    self.errorContextLimit = max(0, errorContextLimit)
    self.logFormat = logFormat
  }

  public static let `default` = AutoLogOutput(name: "Console")

  /// Returns `true` when this output profile should receive the supplied event.
  ///
  /// Routing, enabled state, event kind, and type-name filters all use the same
  /// rules as the runtime logger and the settings live preview.
  public func matches(_ event: AutoLogEvent) -> Bool {
    guard isEnabled else { return false }
    guard routeMatches(eventRoutes: event.routes) else { return false }
    guard eventTypes.contains(event.outputEventType) else { return false }

    let filters = typeNameFilters
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
    guard !filters.isEmpty else { return true }

    return filters.contains { token in
      event.inferredTypeName.localizedCaseInsensitiveContains(token)
    }
  }

  private func routeMatches(eventRoutes: Set<AutoLogRoute>) -> Bool {
    if route == .console {
      return eventRoutes.isEmpty || eventRoutes.contains(.console)
    }

    return eventRoutes.contains(route)
  }
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

  /// Optional per-destination output profiles.
  ///
  /// When empty, runtime behavior falls back to the legacy single-output fields
  /// above (`emitStartEvents`, `measureTimingDefault`, `measureTimingDepths`,
  /// and `logFormat`).
  public var outputs: [AutoLogOutput]

  public init(
    emitStartEvents: Bool = true,
    measureTimingDefault: Bool = true,
    deduplicateWithin: AutoLogDeduplication? = nil,
    measureTimingDepths: Set<Int>? = nil,
    logFormat: LogFormat = .default,
    outputs: [AutoLogOutput] = []
  ) {
    self.emitStartEvents = emitStartEvents
    self.measureTimingDefault = measureTimingDefault
    self.deduplicateWithin = deduplicateWithin
    self.measureTimingDepths = measureTimingDepths
    self.logFormat = logFormat
    self.outputs = outputs
  }

  public static let `default` = AutoLogConfiguration()

  private enum CodingKeys: String, CodingKey {
    case emitStartEvents
    case measureTimingDefault
    case deduplicateWithin
    case measureTimingDepths
    case logFormat
    case outputs
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    emitStartEvents = try container.decodeIfPresent(Bool.self, forKey: .emitStartEvents) ?? true
    measureTimingDefault = try container.decodeIfPresent(Bool.self, forKey: .measureTimingDefault) ?? true
    deduplicateWithin = try container.decodeIfPresent(AutoLogDeduplication.self, forKey: .deduplicateWithin)
    measureTimingDepths = try container.decodeIfPresent(Set<Int>.self, forKey: .measureTimingDepths)
    logFormat = try container.decodeIfPresent(LogFormat.self, forKey: .logFormat) ?? .default
    outputs = try container.decodeIfPresent([AutoLogOutput].self, forKey: .outputs) ?? []
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(emitStartEvents, forKey: .emitStartEvents)
    try container.encode(measureTimingDefault, forKey: .measureTimingDefault)
    try container.encodeIfPresent(deduplicateWithin, forKey: .deduplicateWithin)
    try container.encodeIfPresent(measureTimingDepths, forKey: .measureTimingDepths)
    try container.encode(logFormat, forKey: .logFormat)
    try container.encode(outputs, forKey: .outputs)
  }

  public var effectiveOutputs: [AutoLogOutput] {
    guard !outputs.isEmpty else {
      return [
        AutoLogOutput(
          name: "Console",
          route: .console,
          measureTiming: measureTimingDefault,
          timingDepths: measureTimingDepths,
          errorContextLimit: 5,
          logFormat: logFormat
        )
      ]
    }

    return outputs
  }

  public func applying(output: AutoLogOutput) -> Self {
    var copy = self
    copy.measureTimingDefault = output.measureTiming
    copy.measureTimingDepths = output.timingDepths
    copy.logFormat = output.logFormat
    copy.outputs = [output]
    return copy
  }

  public var maxErrorContextLimit: Int {
    max(effectiveOutputs.map(\.errorContextLimit).max() ?? 0, 5)
  }
}

extension AutoLogEvent {
  /// The event kind used by output-profile routing and filtering.
  public var outputEventType: AutoLogOutputEventType {
    if let source, declaration == source.description {
      return .interaction
    }

    if let level = level as? LogLevel, level == .start {
      return .start
    }

    if case .failure = result {
      return .failure
    }

    return .success
  }

  /// Best-effort type name derived from the source location.
  ///
  /// Output profiles use this for simple text filtering such as `ViewModel`.
  public var inferredTypeName: String {
    let filename = location.split(separator: "/").last.map(String.init) ?? location
    let stem = filename.components(separatedBy: ".swift").first ?? filename
    return stem.isEmpty ? "Unknown" : stem
  }
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

    let normalized = configuration.normalizedForCurrentDefaults()
    if normalized != configuration {
      saveConfiguration(normalized)
    }

    return normalized
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

private extension AutoLogConfiguration {
  func normalizedForCurrentDefaults() -> Self {
    var copy = self

    if copy.logFormat == .legacyDefault {
      copy.logFormat = .default
    }

    copy.outputs = copy.outputs.map { output in
      guard output.logFormat == .legacyDefault else { return output }
      var migrated = output
      migrated.logFormat = .default
      return migrated
    }

    return copy
  }
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
