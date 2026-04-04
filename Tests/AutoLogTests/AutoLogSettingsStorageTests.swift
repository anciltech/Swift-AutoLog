import AutoLog
import Foundation
import Testing

@Suite(.serialized)
struct AutoLogSettingsStorageTests {
  @Test
  func customDefaultsSuiteAndKeysStillDriveStoredSettings() {
    let originalUserDefaults = AutoLogSettingsStorage.userDefaults
    let originalMeasureTimingKey = AutoLogSettingsStorage.measureTimingKey
    let originalMeasureTimingDefault = AutoLogSettingsStorage.measureTimingDefault
    let originalFormatKey = AutoLogSettingsStorage.formatKey

    let suiteName = "AutoLogSettingsStorageTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!

    defer {
      defaults.removePersistentDomain(forName: suiteName)
      AutoLogSettingsStorage.userDefaults = originalUserDefaults
      AutoLogSettingsStorage.measureTimingKey = originalMeasureTimingKey
      AutoLogSettingsStorage.measureTimingDefault = originalMeasureTimingDefault
      AutoLogSettingsStorage.formatKey = originalFormatKey
    }

    AutoLogSettingsStorage.userDefaults = defaults
    AutoLogSettingsStorage.measureTimingKey = "measure-timing.test"
    AutoLogSettingsStorage.measureTimingDefault = false

    #expect(AutoLogSettingsStorage.measureTiming() == false)

    AutoLogSettingsStorage.setMeasureTiming(true)
    #expect(AutoLogSettingsStorage.measureTiming() == true)

    let format = LogFormat(mainLine: [.depthArrow, .statusEmoji, .functionName])
    AutoLogSettingsStorage.formatKey = "format.test"
    AutoLogSettingsStorage.setLogFormat(format)

    #expect(AutoLogSettingsStorage.logFormat() == format)
  }
}
