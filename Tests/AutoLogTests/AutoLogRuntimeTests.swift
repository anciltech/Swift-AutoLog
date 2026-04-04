import AutoLog
import Foundation
import Testing

@Suite(.serialized)
struct AutoLogRuntimeTests {
  @Test
  func configurationStore_roundTripsConfigurationAndRevision() {
    let suiteName = "AutoLogRuntimeTests.store.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let store = AutoLogConfigurationStore(userDefaults: defaults)
    let configuration = AutoLogConfiguration(
      emitStartEvents: false,
      measureTimingDefault: false,
      measureTimingDepths: [2, 3],
      logFormat: LogFormat(mainLine: [.depthArrow, .statusEmoji, .functionName])
    )

    #expect(store.loadRevision() == 0)
    #expect(store.loadConfiguration() == nil)

    store.saveConfiguration(configuration)

    #expect(store.loadConfiguration() == configuration)
    #expect(store.loadRevision() == 1)
  }

  @Test
  func withConfiguration_restoresPreviousRuntimeAfterScope() {
    let originalRuntime = AutoLog.runtimeSnapshot()
    let override = AutoLogConfiguration(
      emitStartEvents: false,
      measureTimingDefault: false,
      measureTimingDepths: [2]
    )

    AutoLog.withConfiguration(override) {
      #expect(AutoLog.runtimeSnapshot().configuration == override)
    }

    #expect(AutoLog.runtimeSnapshot().configuration == originalRuntime.configuration)
  }

  @Test
  func bootstrap_withConfigurationInstallsCustomConfiguration() {
    let configuration = AutoLogConfiguration(
      emitStartEvents: false,
      measureTimingDefault: false,
      measureTimingDepths: [2, 3]
    )
    defer { AutoLog.bootstrap() }

    AutoLog.bootstrap(configuration: configuration)

    #expect(AutoLog.runtimeSnapshot().configuration == configuration)
  }

  @Test
  func runtimeSnapshot_reloadsPersistedConfigurationWhenRevisionChanges() {
    let suiteName = "AutoLogRuntimeTests.reload.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    defer {
      defaults.removePersistentDomain(forName: suiteName)
      AutoLog.bootstrap()
    }

    let store = AutoLogConfigurationStore(userDefaults: defaults)
    let initial = AutoLogConfiguration(
      emitStartEvents: true,
      measureTimingDefault: true,
      logFormat: .default
    )
    let updated = AutoLogConfiguration(
      emitStartEvents: false,
      measureTimingDefault: false,
      measureTimingDepths: [3],
      logFormat: LogFormat(mainLine: [.statusEmoji, .functionName])
    )

    AutoLog.bootstrap(
      logger: MockLogger(),
      configuration: initial,
      configurationStore: store,
      refreshInterval: .seconds(0)
    )

    #expect(AutoLog.runtimeSnapshot().configuration == initial)

    store.saveConfiguration(updated)
    AutoLog.reloadConfigurationIfNeeded()

    #expect(AutoLog.runtimeSnapshot().configuration == updated)
  }

  @Test
  func macroGeneratedFunctionsUseEntrySnapshotForStartAndFinish() async {
    let suiteName = "AutoLogRuntimeTests.snapshot.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    defer {
      defaults.removePersistentDomain(forName: suiteName)
      AutoLog.bootstrap()
    }

    let logger = MockLogger()
    let store = AutoLogConfigurationStore(userDefaults: defaults)
    let initial = AutoLogConfiguration(
      emitStartEvents: true,
      measureTimingDefault: true,
      logFormat: .default
    )
    let updated = AutoLogConfiguration(
      emitStartEvents: true,
      measureTimingDefault: false,
      logFormat: LogFormat(mainLine: [.statusEmoji, .functionName])
    )

    AutoLog.bootstrap(
      logger: logger,
      configuration: initial,
      configurationStore: store,
      refreshInterval: .seconds(0)
    )

    let fixture = SnapshotFixture(updatedConfiguration: updated)
    fixture.flipConfigurationMidCall()

    #expect(logger.events.count == 2)
    #expect(logger.configurations.count == 2)
    #expect(logger.configurations[0] == initial)
    #expect(logger.configurations[1] == initial)
    #expect(AutoLog.runtimeSnapshot().configuration == updated)

    _ = await fixture.flipConfigurationMidCallAsync()
    #expect(logger.configurations.suffix(2).allSatisfy { $0 == updated })
  }
}

private struct SnapshotFixture {
  let updatedConfiguration: AutoLogConfiguration

  @Log
  func flipConfigurationMidCall() {
    AutoLog.updateConfiguration(updatedConfiguration, persist: true)
  }

  @Log
  func flipConfigurationMidCallAsync() async -> Bool {
    AutoLog.updateConfiguration(updatedConfiguration, persist: true)
    return true
  }
}
