import Foundation

/// Shared defaults used by app-level settings UIs.
///
/// Consumers can override these values during app startup to customize
/// persistence keys, backing storage, and fallback values.
public enum LoggableSettingsStorage {
  public static nonisolated(unsafe) var userDefaults: UserDefaults = .standard

  // MARK: - Omit parameters

  public static nonisolated(unsafe) var omitParametersKey: String = "log.omitParameters"
  public static nonisolated(unsafe) var omitResultKey: String = "log.omitResult"

  public static nonisolated(unsafe) var omitParametersDefault: Bool = false
  public static nonisolated(unsafe) var omitResultDefault: Bool = false

  public static func omitParameters() -> Bool {
    guard userDefaults.object(forKey: omitParametersKey) != nil
    else { return omitParametersDefault }
    return userDefaults.bool(forKey: omitParametersKey)
  }

  public static func setOmitParameters(_ value: Bool) {
    userDefaults.set(value, forKey: omitParametersKey)
  }

  public static func omitResult() -> Bool {
    guard userDefaults.object(forKey: omitResultKey) != nil
    else { return omitResultDefault }
    return userDefaults.bool(forKey: omitResultKey)
  }

  public static func setOmitResult(_ value: Bool) {
    userDefaults.set(value, forKey: omitResultKey)
  }

  // MARK: - Start events

  /// Whether the macro should emit a 🔵 start event before a function executes.
  /// Defaults to `true`. Set to `false` during app init to suppress start events globally.
  public static nonisolated(unsafe) var emitStartEvents: Bool = true

  // MARK: - Timing

  /// Whether `@Logged` functions should display timing by default.
  /// Individual functions may override this with `@Log(measure: true/false)`.
  /// Defaults to `true`.
  public static nonisolated(unsafe) var measureTimingDefault: Bool = true

  public static nonisolated(unsafe) var measureTimingKey: String = "log.measureTiming"

  /// Restrict timing display to specific depth levels (e.g. `[2]` for ViewModel only).
  /// `nil` means show timing for all depths when enabled.
  public static nonisolated(unsafe) var measureTimingDepths: Set<Int>? = nil

  public static func measureTiming() -> Bool {
    guard userDefaults.object(forKey: measureTimingKey) != nil
    else { return measureTimingDefault }
    return userDefaults.bool(forKey: measureTimingKey)
  }

  public static func setMeasureTiming(_ value: Bool) {
    userDefaults.set(value, forKey: measureTimingKey)
  }
}

extension Loggable where Self == LoggableLogger {
  public static var cleanArchitecture: Self {
    LoggableLogger(formatter: CompactFormatter(profile: .cleanArchitecture))
  }

  public static var mvvm: Self {
    LoggableLogger(formatter: CompactFormatter(profile: .mvvm))
  }
}
