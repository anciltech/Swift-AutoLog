import Foundation
import Synchronization

private struct UserDefaultsBox: @unchecked Sendable {
  var value: UserDefaults
}

private struct AutoLogSettingsState {
  var userDefaultsBox: UserDefaultsBox = UserDefaultsBox(value: .standard)
  var omitParametersKey: String = "log.omitParameters"
  var omitResultKey: String = "log.omitResult"
  var omitParametersDefault: Bool = false
  var omitResultDefault: Bool = false
  var emitStartEvents: Bool = true
  var measureTimingDefault: Bool = true
  var measureTimingKey: String = "log.measureTiming"
  var measureTimingDepths: Set<Int>? = nil
  var formatKey: String = "log.format"

  var userDefaults: UserDefaults {
    get { userDefaultsBox.value }
    set { userDefaultsBox = UserDefaultsBox(value: newValue) }
  }
}

/// Shared defaults used by app-level settings UIs.
///
/// Consumers can override these values during app startup to customize
/// persistence keys, backing storage, and fallback values.
public enum AutoLogSettingsStorage {
  private static let state = Mutex(AutoLogSettingsState())

  private static func snapshot() -> AutoLogSettingsState {
    state.withLock { $0 }
  }

  public static var userDefaults: UserDefaults {
    get { snapshot().userDefaults }
    set { state.withLock { $0.userDefaults = newValue } }
  }

  // MARK: - Omit parameters

  public static var omitParametersKey: String {
    get { snapshot().omitParametersKey }
    set { state.withLock { $0.omitParametersKey = newValue } }
  }
  public static var omitResultKey: String {
    get { snapshot().omitResultKey }
    set { state.withLock { $0.omitResultKey = newValue } }
  }

  public static var omitParametersDefault: Bool {
    get { snapshot().omitParametersDefault }
    set { state.withLock { $0.omitParametersDefault = newValue } }
  }
  public static var omitResultDefault: Bool {
    get { snapshot().omitResultDefault }
    set { state.withLock { $0.omitResultDefault = newValue } }
  }

  public static func omitParameters() -> Bool {
    let snapshot = snapshot()
    guard snapshot.userDefaults.object(forKey: snapshot.omitParametersKey) != nil
    else { return snapshot.omitParametersDefault }
    return snapshot.userDefaults.bool(forKey: snapshot.omitParametersKey)
  }

  public static func setOmitParameters(_ value: Bool) {
    let snapshot = snapshot()
    snapshot.userDefaults.set(value, forKey: snapshot.omitParametersKey)
  }

  public static func omitResult() -> Bool {
    let snapshot = snapshot()
    guard snapshot.userDefaults.object(forKey: snapshot.omitResultKey) != nil
    else { return snapshot.omitResultDefault }
    return snapshot.userDefaults.bool(forKey: snapshot.omitResultKey)
  }

  public static func setOmitResult(_ value: Bool) {
    let snapshot = snapshot()
    snapshot.userDefaults.set(value, forKey: snapshot.omitResultKey)
  }

  // MARK: - Start events

  /// Whether the macro should emit a 🔵 start event before a function executes.
  /// Defaults to `true`. Set to `false` during app init to suppress start events globally.
  public static var emitStartEvents: Bool {
    get { snapshot().emitStartEvents }
    set { state.withLock { $0.emitStartEvents = newValue } }
  }

  // MARK: - Timing

  /// Whether `@AutoLog` functions should display timing by default.
  /// Individual functions may override this with `@Log(measure: true/false)`.
  /// Defaults to `true`.
  public static var measureTimingDefault: Bool {
    get { snapshot().measureTimingDefault }
    set { state.withLock { $0.measureTimingDefault = newValue } }
  }

  public static var measureTimingKey: String {
    get { snapshot().measureTimingKey }
    set { state.withLock { $0.measureTimingKey = newValue } }
  }

  /// Restrict timing display to specific depth levels (e.g. `[2]` for ViewModel only).
  /// `nil` means show timing for all depths when enabled.
  public static var measureTimingDepths: Set<Int>? {
    get { snapshot().measureTimingDepths }
    set { state.withLock { $0.measureTimingDepths = newValue } }
  }

  public static func measureTiming() -> Bool {
    let snapshot = snapshot()
    guard snapshot.userDefaults.object(forKey: snapshot.measureTimingKey) != nil
    else { return snapshot.measureTimingDefault }
    return snapshot.userDefaults.bool(forKey: snapshot.measureTimingKey)
  }

  public static func setMeasureTiming(_ value: Bool) {
    let snapshot = snapshot()
    snapshot.userDefaults.set(value, forKey: snapshot.measureTimingKey)
  }

  // MARK: - Log Format

  /// The UserDefaults key used to persist the active ``LogFormat``.
  ///
  /// Override before app launch if you need a custom key.
  public static var formatKey: String {
    get { snapshot().formatKey }
    set { state.withLock { $0.formatKey = newValue } }
  }

  /// Returns the currently stored ``LogFormat``, or ``LogFormat/default`` if none is set.
  public static func logFormat() -> LogFormat {
    let snapshot = snapshot()
    guard
      let data = snapshot.userDefaults.data(forKey: snapshot.formatKey),
      let format = try? JSONDecoder().decode(LogFormat.self, from: data)
    else { return .default }
    return format
  }

  /// Persists a ``LogFormat`` to UserDefaults so ``CompactFormatter`` picks it up.
  ///
  /// Call this from your app's startup code, or let the AutoLogSettings companion
  /// app write it for you.
  ///
  /// ```swift
  /// // App startup
  /// AutoLogSettingsStorage.setLogFormat(
  ///   LogFormat(mainLine: [.depthArrow, .statusEmoji, .functionName, .parameters])
  /// )
  /// ```
  public static func setLogFormat(_ format: LogFormat) {
    let snapshot = snapshot()
    guard let data = try? JSONEncoder().encode(format) else { return }
    snapshot.userDefaults.set(data, forKey: snapshot.formatKey)
  }

  /// Removes any stored format, causing ``CompactFormatter`` to revert to
  /// ``LogFormat/default``.
  public static func resetLogFormat() {
    let snapshot = snapshot()
    snapshot.userDefaults.removeObject(forKey: snapshot.formatKey)
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
