@testable import AutoLog
import Foundation
import Testing

@Suite(.serialized)
struct AutoLogRuntimeTests {
  @Test @MainActor
  func asyncContextWrappers_preserveCallerActorIsolation() async {
    var value = 0

    let depthResult = await AutoLog.withCallSiteDepth(2) {
      await Task.yield()
      value += 1
      return value
    }
    let sourceResult = await AutoLogInteraction.system("Main actor test").log {
      await Task.yield()
      value += 1
      return value
    }
    let taskResult = await AutoLog.logTask("Main actor test") {
      await Task.yield()
      value += 1
      return value
    }

    #expect(depthResult == 1)
    #expect(sourceResult == 2)
    #expect(taskResult == 3)
  }

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
      deduplicateWithin: .seconds(1),
      measureTimingDepths: [2, 3],
      logFormat: LogFormat(mainLine: [.depthArrow, .statusEmoji, .functionName]),
      outputs: [
        AutoLogOutput(
          name: "Console Results",
          route: .console,
          eventTypes: [.success, .failure],
          typeNameFilters: ["ViewModel"],
          measureTiming: false,
          timingDepths: [2],
          errorContextLimit: 10,
          logFormat: LogFormat(mainLine: [.statusEmoji, .functionName])
        )
      ]
    )

    #expect(store.loadRevision() == 0)
    #expect(store.loadConfiguration() == nil)

    store.saveConfiguration(configuration)

    #expect(store.loadConfiguration() == configuration)
    #expect(store.loadRevision() == 1)
  }

  @Test
  func configurationStore_migratesLegacyDefaultFormatToColumnLayout() {
    let suiteName = "AutoLogRuntimeTests.migration.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let store = AutoLogConfigurationStore(userDefaults: defaults)
    let legacyFormat = LogFormat(mainLine: [
      .depthArrow,
      .statusEmoji,
      .typeName,
      .dotSeparator,
      .functionName,
      .parameters,
      .effectSpecifiers,
      .returnValue,
      .timing,
    ])
    let legacyConfiguration = AutoLogConfiguration(
      logFormat: legacyFormat,
      outputs: [
        AutoLogOutput(
          name: "Console",
          logFormat: legacyFormat
        ),
        AutoLogOutput(
          name: "Custom",
          route: .firebase,
          logFormat: LogFormat(mainLine: [.statusEmoji, .functionName])
        )
      ]
    )

    store.saveConfiguration(legacyConfiguration)

    let loaded = store.loadConfiguration()

    #expect(loaded?.logFormat == .default)
    #expect(loaded?.outputs.first?.logFormat == .default)
    #expect(loaded?.outputs.last?.logFormat == LogFormat(mainLine: [.statusEmoji, .functionName]))
  }

  @Test
  func buildConfiguration_derivesDefaultEmissionsFromEffectiveOutputs() {
    let buildConfiguration = AutoLogConfiguration.default.derivedBuildConfiguration

    #expect(buildConfiguration.emissions == [
      .starts,
      .successes,
      .failures,
      .warnings,
    ])
    #expect(buildConfiguration.measureTiming)
    #expect(buildConfiguration.macroEmitArgument == "[.starts, .successes, .failures, .warnings]")
    #expect(buildConfiguration.macroMeasureArgument == nil)
  }

  @Test
  func buildConfiguration_derivesDiagnosticsAndTimingFromOutputProfiles() {
    let configuration = AutoLogConfiguration(
      outputs: [
        AutoLogOutput(
          name: "Production Console",
          route: .console,
          eventTypes: [.failure, .warning],
          measureTiming: false
        )
      ]
    )

    let buildConfiguration = configuration.derivedBuildConfiguration

    #expect(buildConfiguration.emissions == [.failures, .warnings])
    #expect(!buildConfiguration.measureTiming)
    #expect(buildConfiguration.macroEmitArgument == "[.failures, .warnings]")
    #expect(buildConfiguration.macroMeasureArgument == "false")
    #expect(buildConfiguration.macroEnvironment == [
      AutoLogBuildConfiguration.macroEmitEnvironmentKey: "[.failures, .warnings]",
      AutoLogBuildConfiguration.macroMeasureEnvironmentKey: "false",
    ])
  }

  @Test
  func buildConfiguration_ignoresRuntimeOnlyFiltersAndDisabledOutputs() {
    let configuration = AutoLogConfiguration(
      outputs: [
        AutoLogOutput(
          name: "Disabled",
          route: .console,
          isEnabled: false,
          eventTypes: [.success, .failure, .warning]
        ),
        AutoLogOutput(
          name: "Filtered",
          route: .splunk,
          eventTypes: [.failure],
          typeNameFilters: ["CheckoutViewModel"]
        ),
        AutoLogOutput(
          name: "Interactions",
          route: .console,
          eventTypes: [.interaction]
        ),
      ]
    )

    let buildConfiguration = configuration.derivedBuildConfiguration

    #expect(buildConfiguration.emissions == [.failures])
    #expect(buildConfiguration.macroEmitArgument == ".failures")
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
  func start_withConfigurationInstallsCustomConfiguration() {
    let configuration = AutoLogConfiguration(
      emitStartEvents: false,
      measureTimingDefault: false,
      measureTimingDepths: [2, 3]
    )
    defer { AutoLog.start() }

    AutoLog.start(configuration: configuration)

    #expect(AutoLog.runtimeSnapshot().configuration == configuration)
  }

  @Test
  func runtimeSnapshot_reloadsPersistedConfigurationWhenRevisionChanges() {
    let suiteName = "AutoLogRuntimeTests.reload.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    defer {
      defaults.removePersistentDomain(forName: suiteName)
      AutoLog.start()
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

    AutoLog.start(
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
      AutoLog.start()
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

    AutoLog.start(
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

  @Test
  func defaultLoggedFunctionSkipsDurationWhenRuntimeTimingIsDisabled() {
    let logger = MockLogger()
    let runtime = AutoLogRuntime(
      logger: logger,
      configuration: AutoLogConfiguration(
        outputs: [
          AutoLogOutput(
            name: "Console",
            route: .console,
            eventTypes: [.interaction, .success, .failure, .warning],
            measureTiming: false
          )
        ]
      )
    )

    AutoLog.withRuntime(runtime) {
      TimingFixture().defaultMeasured()
    }

    #expect(logger.events.count == 1)
    #expect(logger.events.first?.duration == nil)
  }

  @Test
  func explicitMeasuredFunctionCapturesDurationWhenRuntimeTimingIsDisabled() {
    let logger = MockLogger()
    let runtime = AutoLogRuntime(
      logger: logger,
      configuration: AutoLogConfiguration(
        outputs: [
          AutoLogOutput(
            name: "Console",
            route: .console,
            eventTypes: [.interaction, .success, .failure, .warning],
            measureTiming: false
          )
        ]
      )
    )

    AutoLog.withRuntime(runtime) {
      TimingFixture().explicitMeasured()
    }

    #expect(logger.events.count == 1)
    #expect(logger.events.first?.duration != nil)
    #expect(logger.events.first?.isMeasuredExplicitly == true)
  }

  @Test
  func macroGeneratedInitializerEmitsCompletion() {
    let logger = MockLogger()
    let runtime = AutoLogRuntime(
      logger: logger,
      configuration: .testConsoleWithoutStart
    )

    AutoLog.withRuntime(runtime) {
      _ = InitializerFixture(name: "Demo")
    }

    #expect(logger.events.count == 1)
    #expect(logger.events.first?.declaration == "init(name: String)")
    #expect(logger.events.first?.parameters["name"] as? String == "Demo")
  }

  @Test
  func macroGeneratedThrowingInitializerEmitsFailure() {
    let logger = MockLogger()
    let runtime = AutoLogRuntime(
      logger: logger,
      configuration: .testConsoleWithoutStart
    )

    AutoLog.withRuntime(runtime) {
      #expect(throws: InitializerFixture.FixtureError.emptyName) {
        _ = try InitializerFixture(validating: "")
      }
    }

    #expect(logger.events.count == 1)
    #expect(logger.events.first?.declaration == "init(validating name: String) throws")
    guard case .failure = logger.events.first?.result else {
      Issue.record("Expected throwing initializer to emit a failure event")
      return
    }
  }

  @Test
  func globalDeduplicationSuppressesRepeatedManualEvents() {
    let logger = MockLogger()
    let runtime = AutoLogRuntime(
      logger: logger,
      configuration: AutoLogConfiguration(
        emitStartEvents: false,
        deduplicateWithin: .seconds(1)
      )
    )

    AutoLog.withRuntime(runtime) {
      let fixture = DeduplicationFixture()
      fixture.emitRepeatedWarning()
      fixture.emitRepeatedWarning()
    }

    #expect(logger.events.count == 1)
    #expect(logger.events.first?.declaration == "No matching SCWindow found")
  }

  @Test
  func functionLevelDeduplicationSuppressesOnlyMatchingEvents() {
    let logger = MockLogger()
    let runtime = AutoLogRuntime(
      logger: logger,
      configuration: .testConsoleWithoutStart
    )

    AutoLog.withRuntime(runtime) {
      let fixture = DeduplicationFixture()
      _ = fixture.sampleSelection(frameID: 7)
      _ = fixture.sampleSelection(frameID: 7)
      _ = fixture.sampleSelection(frameID: 8)
    }

    #expect(logger.events.count == 2)
    #expect(logger.events.map(\.declaration) == [
      "func sampleSelection(frameID: Int) -> Bool",
      "func sampleSelection(frameID: Int) -> Bool",
    ])
    #expect((logger.events.first?.deduplicateWithin) == .seconds(1))
  }

  @Test
  func omissionRuleTrackingPrunesFingerprints() {
    var state = AutoLogDeduplicationState()

    for index in 0...600 {
      _ = state.shouldEmitForOmissionRule(
        fingerprint: "omitted-\(index)",
        upToCount: 1
      )
    }

    #expect(state.omissionCountByFingerprint.count <= 512)
  }

  @Test
  func typedArrayEmission_generatesSelectedPaths() {
    let logger = MockLogger()
    let runtime = AutoLogRuntime(
      logger: logger,
      configuration: .testConsoleWithoutStart
    )

    AutoLog.withRuntime(runtime) {
      let fixture = TypedEmissionFixture()
      #expect(fixture.succeed() == 42)
      #expect(throws: TypedEmissionFixture.FixtureError.fatal) {
        try fixture.failAfterHandlingRecoverableError()
      }
    }

    #expect(logger.events.count == 3)
    #expect(logger.events[0].outputEventType == .success)
    #expect(logger.events[1].handledError != nil)
    #expect(logger.events[1].outputEventType == .warning)
    #expect(logger.events[2].outputEventType == .failure)
    guard case .failure = logger.events[2].result else {
      Issue.record("Expected typed failure emission to capture the thrown error")
      return
    }
  }

  @Test
  func typeLevelFailuresOnlyMeasureFalse_skipsSuccessAndDuration() {
    let logger = MockLogger()
    let runtime = AutoLogRuntime(
      logger: logger,
      configuration: .testConsoleWithoutStart
    )

    AutoLog.withRuntime(runtime) {
      let fixture = TypeLevelFailuresOnlyNoTimingFixture()
      fixture.succeed()
      #expect(throws: TypeLevelFailuresOnlyNoTimingFixture.FixtureError.failed) {
        try fixture.fail()
      }
    }

    #expect(logger.events.count == 1)
    #expect(logger.events.first?.outputEventType == .failure)
    #expect(logger.events.first?.duration == nil)
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

private struct DeduplicationFixture {
  func emitRepeatedWarning() {
    AutoLog.warning("No matching SCWindow found")
  }

  @Deduplicate(.seconds(1))
  @Log
  func sampleSelection(frameID: Int) -> Bool {
    frameID.isMultiple(of: 2)
  }
}

private struct TimingFixture {
  @Log
  func defaultMeasured() {}

  @Log(measure: true)
  func explicitMeasured() {}
}

private struct TypedEmissionFixture {
  enum FixtureError: Error {
    case recoverable
    case fatal
  }

  @Log(emit: [.successes])
  func succeed() -> Int {
    42
  }

  @Log(emit: [.failures, .warnings])
  func failAfterHandlingRecoverableError() throws {
    do {
      throw FixtureError.recoverable
    } catch {
      // The typed `.warnings` emission keeps this handled-error row.
    }

    throw FixtureError.fatal
  }
}

@AutoLog(emit: .failures, measure: false)
private struct TypeLevelFailuresOnlyNoTimingFixture {
  enum FixtureError: Error {
    case failed
  }

  func succeed() {}

  func fail() throws {
    throw FixtureError.failed
  }
}

private struct InitializerFixture {
  enum FixtureError: Error {
    case emptyName
  }

  let name: String

  @Log
  init(name: String) {
    self.name = name
  }

  @Log
  init(validating name: String) throws {
    guard !name.isEmpty else {
      throw FixtureError.emptyName
    }
    self.name = name
  }
}
