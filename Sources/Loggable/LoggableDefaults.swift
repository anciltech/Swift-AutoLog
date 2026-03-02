import Foundation

/// Shared defaults used by app-level settings UIs.
///
/// Consumers can override these values during app startup to customize
/// persistence keys, backing storage, and fallback values.
public enum LoggableSettingsStorage {
  public static nonisolated(unsafe) var userDefaults: UserDefaults = .standard

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
}

extension Loggable where Self == LoggableLogger {
  public static var cleanArchitecture: Self {
    LoggableLogger(formatter: CompactFormatter(profile: .cleanArchitecture))
  }

  public static var mvvm: Self {
    LoggableLogger(formatter: CompactFormatter(profile: .mvvm))
  }
}
