import Foundation

private struct UserDefaultsBox: @unchecked Sendable {
  var value: UserDefaults
}

public enum AutoLogOutputEventType: String, Sendable, Codable, CaseIterable, Hashable {
  case interaction
  case start
  case warning
  case success
  case failure
}

public enum AutoLogParameterPrivacy: Sendable, Codable, Equatable, Hashable {
  case include
  case omit
  case allowList(Set<String>)

  public func filteredParameters(_ parameters: [String: Any]) -> [String: Any] {
    switch self {
    case .include:
      return parameters
    case .omit:
      return [:]
    case .allowList(let allowedKeys):
      return parameters.filter { allowedKeys.contains($0.key) }
    }
  }
}

public struct AutoLogOutput: Sendable, Codable, Equatable, Identifiable {
  public var id: String
  public var name: String
  public var route: AutoLogRoute
  public var isEnabled: Bool
  public var eventTypes: Set<AutoLogOutputEventType>
  public var typeNameFilters: [String] {
    didSet {
      typeNameFilters = Self.normalizedTypeNameFilters(typeNameFilters)
    }
  }
  public var measureTiming: Bool
  public var timingDepths: Set<Int>?
  public var normalizedTiming: Bool
  public var errorContextLimit: Int
  public var failureContextTriggerLimit: Int
  public var logFormat: LogFormat
  public var parameterPrivacy: AutoLogParameterPrivacy
  public var metadataKeyAllowList: Set<String>?

  public init(
    id: String = UUID().uuidString,
    name: String,
    route: AutoLogRoute = .console,
    isEnabled: Bool = true,
    eventTypes: Set<AutoLogOutputEventType> = Set(AutoLogOutputEventType.allCases),
    typeNameFilters: [String] = [],
    measureTiming: Bool = true,
    timingDepths: Set<Int>? = nil,
    normalizedTiming: Bool = false,
    errorContextLimit: Int = 5,
    failureContextTriggerLimit: Int = 0,
    logFormat: LogFormat = .default,
    parameterPrivacy: AutoLogParameterPrivacy? = nil,
    metadataKeyAllowList: Set<String>? = nil
  ) {
    self.id = id
    self.name = name
    self.route = route
    self.isEnabled = isEnabled
    self.eventTypes = eventTypes
    self.typeNameFilters = Self.normalizedTypeNameFilters(typeNameFilters)
    self.measureTiming = measureTiming
    self.timingDepths = timingDepths
    self.normalizedTiming = normalizedTiming
    self.errorContextLimit = max(0, errorContextLimit)
    self.failureContextTriggerLimit = max(0, failureContextTriggerLimit)
    self.logFormat = logFormat
    self.parameterPrivacy = parameterPrivacy ?? Self.defaultParameterPrivacy(for: route)
    self.metadataKeyAllowList = metadataKeyAllowList
  }

  public static let consoleDefault = AutoLogOutput(
    name: "Console",
    route: .console,
    eventTypes: [.interaction, .start, .success, .failure, .warning],
    typeNameFilters: []
  )

  public static let `default` = AutoLogOutput.consoleDefault

  private enum CodingKeys: String, CodingKey {
    case id
    case name
    case route
    case isEnabled
    case eventTypes
    case typeNameFilters
    case measureTiming
    case timingDepths
    case normalizedTiming
    case errorContextLimit
    case failureContextTriggerLimit
    case logFormat
    case parameterPrivacy
    case metadataKeyAllowList
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)
    route = try container.decodeIfPresent(AutoLogRoute.self, forKey: .route) ?? .console
    isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    eventTypes = try container.decodeIfPresent(Set<AutoLogOutputEventType>.self, forKey: .eventTypes)
      ?? Set(AutoLogOutputEventType.allCases)
    typeNameFilters = Self.normalizedTypeNameFilters(
      try container.decodeIfPresent([String].self, forKey: .typeNameFilters) ?? []
    )
    measureTiming = try container.decodeIfPresent(Bool.self, forKey: .measureTiming) ?? true
    timingDepths = try container.decodeIfPresent(Set<Int>.self, forKey: .timingDepths)
    normalizedTiming = try container.decodeIfPresent(Bool.self, forKey: .normalizedTiming) ?? false
    errorContextLimit = max(0, try container.decodeIfPresent(Int.self, forKey: .errorContextLimit) ?? 5)
    failureContextTriggerLimit = max(
      0,
      try container.decodeIfPresent(Int.self, forKey: .failureContextTriggerLimit) ?? 0
    )
    logFormat = try container.decodeIfPresent(LogFormat.self, forKey: .logFormat) ?? .default
    parameterPrivacy = try container.decodeIfPresent(AutoLogParameterPrivacy.self, forKey: .parameterPrivacy)
      ?? Self.defaultParameterPrivacy(for: route)
    metadataKeyAllowList = try container.decodeIfPresent(Set<String>.self, forKey: .metadataKeyAllowList)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(name, forKey: .name)
    try container.encode(route, forKey: .route)
    try container.encode(isEnabled, forKey: .isEnabled)
    try container.encode(eventTypes, forKey: .eventTypes)
    try container.encode(typeNameFilters, forKey: .typeNameFilters)
    try container.encode(measureTiming, forKey: .measureTiming)
    try container.encodeIfPresent(timingDepths, forKey: .timingDepths)
    try container.encode(normalizedTiming, forKey: .normalizedTiming)
    try container.encode(errorContextLimit, forKey: .errorContextLimit)
    try container.encode(failureContextTriggerLimit, forKey: .failureContextTriggerLimit)
    try container.encode(logFormat, forKey: .logFormat)
    try container.encode(parameterPrivacy, forKey: .parameterPrivacy)
    try container.encodeIfPresent(metadataKeyAllowList, forKey: .metadataKeyAllowList)
  }

  /// Returns `true` when this output profile should receive the supplied event.
  ///
  /// Routing, enabled state, event kind, and type-name filters all use the same
  /// rules as the runtime logger and the settings live preview.
  public func matches(_ event: AutoLogEvent) -> Bool {
    guard isEnabled else { return false }
    guard routeMatches(eventRoutes: event.routes) else { return false }
    guard eventTypes.contains(event.outputEventType) else { return false }

    return typeNameMatches(event)
  }

  public func canReceiveTiming(for event: AutoLogEvent) -> Bool {
    guard isEnabled, measureTiming else { return false }
    guard routeMatches(eventRoutes: event.routes) else { return false }
    return typeNameMatches(event)
  }

  private func typeNameMatches(_ event: AutoLogEvent) -> Bool {
    guard !typeNameFilters.isEmpty else { return true }

    return typeNameFilters.contains { token in
      event.inferredTypeName.localizedCaseInsensitiveContains(token)
    }
  }

  private func routeMatches(eventRoutes: Set<AutoLogRoute>) -> Bool {
    eventRoutes.isEmpty || eventRoutes.contains(route)
  }

  private static func normalizedTypeNameFilters(_ filters: [String]) -> [String] {
    filters
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  private static func defaultParameterPrivacy(for route: AutoLogRoute) -> AutoLogParameterPrivacy {
    route == .console ? .include : .omit
  }
}

/// Live-tunable logging behavior shared across app processes.
public struct AutoLogConfiguration: Sendable, Codable, Equatable {
  /// Legacy compatibility flag for persisted configurations.
  ///
  /// New code should include or omit ``AutoLogOutputEventType/start`` in each
  /// ``AutoLogOutput/eventTypes`` set instead.
  public var emitStartEvents: Bool

  /// Whether `@AutoLog` functions should display timing by default.
  public var measureTimingDefault: Bool

  /// Suppresses repeated identical log entries within the supplied time window.
  /// `nil` disables global duplicate suppression.
  public var deduplicateWithin: AutoLogDeduplication?

  /// Restrict timing display to specific depth levels (e.g. `[2]` for ViewModel only).
  /// `nil` means show timing for all depths when enabled.
  public var measureTimingDepths: Set<Int>?

  /// Renders measured durations as fixed-width seconds such as `0.00s`.
  public var normalizedTiming: Bool

  /// Limits failure context to entries emitted since the last N interaction or start triggers.
  /// `0` means no trigger-based trimming.
  public var failureContextTriggerLimit: Int

  /// The visual layout used by ``CompactFormatter`` when no formatter-local override exists.
  public var logFormat: LogFormat

  /// Optional per-destination output profiles.
  ///
  /// When empty, runtime behavior falls back to ``AutoLogOutput/consoleDefault``.
  public var outputs: [AutoLogOutput]

  public init(
    emitStartEvents: Bool = true,
    measureTimingDefault: Bool = true,
    deduplicateWithin: AutoLogDeduplication? = nil,
    measureTimingDepths: Set<Int>? = nil,
    normalizedTiming: Bool = false,
    failureContextTriggerLimit: Int = 0,
    logFormat: LogFormat = .default,
    outputs: [AutoLogOutput] = []
  ) {
    self.emitStartEvents = emitStartEvents
    self.measureTimingDefault = measureTimingDefault
    self.deduplicateWithin = deduplicateWithin
    self.measureTimingDepths = measureTimingDepths
    self.normalizedTiming = normalizedTiming
    self.failureContextTriggerLimit = max(0, failureContextTriggerLimit)
    self.logFormat = logFormat
    self.outputs = outputs
  }

  public static let `default` = AutoLogConfiguration()

  private enum CodingKeys: String, CodingKey {
    case emitStartEvents
    case measureTimingDefault
    case deduplicateWithin
    case measureTimingDepths
    case normalizedTiming
    case failureContextTriggerLimit
    case logFormat
    case outputs
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    emitStartEvents = try container.decodeIfPresent(Bool.self, forKey: .emitStartEvents) ?? true
    measureTimingDefault = try container.decodeIfPresent(Bool.self, forKey: .measureTimingDefault) ?? true
    deduplicateWithin = try container.decodeIfPresent(AutoLogDeduplication.self, forKey: .deduplicateWithin)
    measureTimingDepths = try container.decodeIfPresent(Set<Int>.self, forKey: .measureTimingDepths)
    normalizedTiming = try container.decodeIfPresent(Bool.self, forKey: .normalizedTiming) ?? false
    failureContextTriggerLimit = max(0, try container.decodeIfPresent(Int.self, forKey: .failureContextTriggerLimit) ?? 0)
    logFormat = try container.decodeIfPresent(LogFormat.self, forKey: .logFormat) ?? .default
    outputs = try container.decodeIfPresent([AutoLogOutput].self, forKey: .outputs) ?? []
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(emitStartEvents, forKey: .emitStartEvents)
    try container.encode(measureTimingDefault, forKey: .measureTimingDefault)
    try container.encodeIfPresent(deduplicateWithin, forKey: .deduplicateWithin)
    try container.encodeIfPresent(measureTimingDepths, forKey: .measureTimingDepths)
    try container.encode(normalizedTiming, forKey: .normalizedTiming)
    try container.encode(failureContextTriggerLimit, forKey: .failureContextTriggerLimit)
    try container.encode(logFormat, forKey: .logFormat)
    try container.encode(outputs, forKey: .outputs)
  }

  public var effectiveOutputs: [AutoLogOutput] {
    guard !outputs.isEmpty else {
      var output = AutoLogOutput.consoleDefault
      output.measureTiming = measureTimingDefault
      output.timingDepths = measureTimingDepths
      output.normalizedTiming = normalizedTiming
      output.failureContextTriggerLimit = failureContextTriggerLimit
      output.logFormat = logFormat
      return [output]
    }

    return outputs
  }

  public func applying(output: AutoLogOutput) -> Self {
    var copy = self
    copy.measureTimingDefault = output.measureTiming
    copy.measureTimingDepths = output.timingDepths
    copy.normalizedTiming = output.normalizedTiming
    copy.failureContextTriggerLimit = output.failureContextTriggerLimit
    copy.logFormat = output.logFormat
    copy.outputs = [output]
    return copy
  }

  public var maxErrorContextLimit: Int {
    max(effectiveOutputs.map(\.errorContextLimit).max() ?? 0, 5)
  }

  public func shouldEmit(_ event: AutoLogEvent) -> Bool {
    effectiveOutputs.contains { $0.matches(event) }
  }

  public func shouldMeasureTiming(for event: AutoLogEvent) -> Bool {
    event.isMeasuredExplicitly || effectiveOutputs.contains { $0.canReceiveTiming(for: event) }
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

    if handledError != nil {
      return .failure
    }

    if case .failure = result {
      return .failure
    }

    if let level = level as? LogLevel, level == .warning {
      return .warning
    }

    return .success
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
