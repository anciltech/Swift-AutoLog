import AutoLog
import Synchronization
import Testing

@Suite(.serialized)
struct AutoLoggerTests {
  static let mock = MockLogger()

  private func requireSendable<T: Sendable>(_ type: T.Type) {}

  @Test
  func autoLogEvent_isSendableForActorLoggingBoundaries() {
    requireSendable(AutoLogEvent.self)
  }

  @Test
  func conditionTrace_preservesAndReportsShortCircuitFailures() {
    var evaluatedRightSide = false

    let trace = AutoLogConditionTrace.evaluate("left && right") { condition in
      condition.term("left", false)
        && condition.term("right", {
          evaluatedRightSide = true
          return true
        }())
    }

    #expect(trace.passed == false)
    #expect(trace.terms.map(\.condition) == ["left"])
    #expect(trace.failingDescription == "left")
    #expect(evaluatedRightSide == false)
  }

  @Test
  func conditionTrace_reportsAllFailedOrTerms() {
    let trace = AutoLogConditionTrace.evaluate("success || notFound") { condition in
      condition.term("success", false) || condition.term("notFound", false)
    }

    #expect(trace.passed == false)
    #expect(trace.failingDescription == "success, notFound")
  }

  @Test
  func whenLoggerAttachedToType_expectedToCaptureAllEvent() async throws {
    // Workaround: @AutoLog(using: MockLogger) triggers a Swift compiler ICE due to
    // existential boxing in macro argument type-checking (ResolveMacroRequest crash).
    // Use @AutoLog (no-arg) with a scoped runtime override instead.
    let runtime = AutoLogRuntime(
      logger: Self.mock,
      configuration: .testConsoleWithoutStart
    )

    await AutoLog.withRuntime(runtime) {
      let testcase = Testcase()

      #expect(throws: Failure.mock) {
        try testcase.mockThrowingFunction()
      }
      #expect(Self.mock.events.count == 1)

      await #expect(throws: Failure.mock) {
        try await testcase.mockAsyncThrowingFunction()
      }
      #expect(Self.mock.events.count == 2)

      testcase.mockFunctionReturningVoidWithErrorLevelAnnotation()
      #expect(Self.mock.events.count == 3)
      #expect(Self.mock.events.last?.level as? MockLevel == MockLevel.error)

      testcase.mockFunctionReturningVoidWithStringErrorLevelAnnotation()
      #expect(Self.mock.events.count == 4)
      #expect(
        {
          if let level = Self.mock.events.last?.level as? String {
            MockLevel(rawValue: level) == MockLevel.error
          } else {
            false
          }
        }()
      )

      _ = testcase.mockFunctionWithMultipleParametersAndOmitParametersAnnotation(100, "% Luck")
      #expect(Self.mock.events.count == 5)
      #expect(Self.mock.events.last?.parameters.isEmpty == true)

      _ = testcase.mockFunctionWitgTagAndOmitResultAnnotation()
      #expect(Self.mock.events.count == 6)
      #expect(Self.mock.events.last?.tags.count == 2)
      #expect(
        {
          return switch Self.mock.events.last?.result {
          case .success(_ as String): false
          case .success(_ as Void): true
          default: false
          }
        }()
      )

      _ = testcase.mockGenericFunctionWithOmitSpecificParameterAnnotationReturingPassedArgument(mock: true)
      #expect(Self.mock.events.count == 7)
      #expect(Self.mock.events.last?.parameters.isEmpty == true)

      #expect(testcase.isCreating == false)
      #expect(Self.mock.events.count == 7)

      let afterUnconditional = Self.mock.events.count
      _ = testcase.mockConditionalFalseResult(flag: false)
      #expect(Self.mock.events.count == afterUnconditional)

      _ = testcase.mockConditionalFalseResult(flag: true)
      #expect(Self.mock.events.count == afterUnconditional + 1)

      let beforeExpectedError = Self.mock.events.count
      #expect(throws: Failure.expectedFlow) {
        try testcase.mockThrowingFunctionWithExpectedError()
      }
      #expect(Self.mock.events.count == beforeExpectedError)

      #expect(throws: Failure.expectedFlow) {
        try testcase.mockThrowingFunctionWithExpectedError()
      }
      #expect(Self.mock.events.count == beforeExpectedError + 1)

      let beforeFilteredError = Self.mock.events.count
      #expect(throws: Failure.iamError) {
        try testcase.mockThrowingIAMStyleError()
      }
      #expect(Self.mock.events.count == beforeFilteredError)

      #expect(throws: Failure.other) {
        try testcase.mockThrowingOtherError()
      }
      #expect(Self.mock.events.count == beforeFilteredError + 1)
    }
  }

  @Test
  func singleRouteTag_isClassifiedWithoutVisibleTags() {
    let event = AutoLogEvent(
      location: "App/Feature.swift:1:1",
      declaration: "func uploadAuditTrail()",
      tags: [AutoLogRoute.splunk]
    )

    #expect(event.routes == [.splunk])
    #expect(event.visibleTags.isEmpty)
  }

  @Test
  func singleVisibleTag_isClassifiedWithoutRoutes() {
    let event = AutoLogEvent(
      location: "App/Feature.swift:1:1",
      declaration: "func uploadAuditTrail()",
      tags: ["audit"]
    )

    #expect(event.routes.isEmpty)
    #expect(event.visibleTags.count == 1)
    #expect(String(describing: event.visibleTags[0]) == "audit")
  }

  @Test
  func parameterLabels_areCachedAndRefreshWhenParametersChange() {
    var event = AutoLogEvent(
      location: "App/Feature.swift:1:1",
      declaration: "func track(zeta: Int, alpha: Int, middle: Int)",
      parameters: [
        "zeta": 3,
        "alpha": 1,
        "middle": 2,
      ]
    )

    #expect(event.parameterLabels == ["alpha", "middle", "zeta"])

    event.parameters = [
      "beta": 2,
      "alpha": 1,
    ]

    #expect(event.parameterLabels == ["alpha", "beta"])
  }

  @Test
  func routeTags_forwardOnlyToMatchingSinks() {
    let sink = MockEventSink(route: .splunk)
    let logger = AutoLogLogger(formatter: MockFormatter(), sinks: [sink])
    let configuration = AutoLogConfiguration(
      outputs: [
        AutoLogOutput(name: "Splunk", route: .splunk)
      ]
    )

    logger.emit(
      event: AutoLogEvent(
        location: "App/Feature.swift:1:1",
        declaration: "func uploadAuditTrail()",
        tags: [AutoLogRoute.splunk]
      ),
      configuration: configuration
    )

    #expect(sink.events.count == 1)
  }

  @Test
  func routeTags_doNotForwardToNonMatchingSinks() {
    let sink = MockEventSink(route: .firebase)
    let logger = AutoLogLogger(formatter: MockFormatter(), sinks: [sink])
    let configuration = AutoLogConfiguration.default

    logger.emit(
      event: AutoLogEvent(
        location: "App/Feature.swift:1:1",
        declaration: "func uploadAuditTrail()",
        tags: [AutoLogRoute.splunk]
      ),
      configuration: configuration
    )

    #expect(sink.events.isEmpty)
  }

  @Test
  func untaggedEventsForwardToMatchingOutputSinks() {
    let sink = MockEventSink(route: .firebase)
    let logger = AutoLogLogger(formatter: MockFormatter(), sinks: [sink])
    let configuration = AutoLogConfiguration(
      outputs: [
        AutoLogOutput(
          name: "Firebase ViewModel Failures",
          route: .firebase,
          eventTypes: [.failure],
          typeNameFilters: ["ViewModel"]
        )
      ]
    )

    logger.emit(
      event: AutoLogEvent(
        location: "App/AuthViewModel.swift:1:1",
        declaration: "func login()",
        result: .failure(Failure.mock)
      ),
      configuration: configuration
    )

    #expect(sink.events.count == 1)
  }

  @Test
  func interactionHelpersForwardThroughMatchingOutputsWithoutRouteTags() {
    let sink = MockEventSink(route: .firebase)
    let runtime = AutoLogRuntime(
      logger: AutoLogLogger(formatter: MockFormatter(), sinks: [sink]),
      configuration: AutoLogConfiguration(
        outputs: [
          AutoLogOutput(
            name: "Firebase Interactions",
            route: .firebase,
            eventTypes: [.interaction]
          )
        ]
      )
    )

    AutoLog.withRuntime(runtime) {
      AutoLog.run(AutoLogInteraction.button("Save")) {}
    }

    #expect(sink.events.count == 1)
    #expect(sink.events.first?.outputEventType == .interaction)
    #expect(sink.events.first?.routes.isEmpty == true)
  }

  @Test
  func startEventsAreControlledByOutputEventTypes() {
    let sink = MockEventSink(route: .firebase)
    let logger = AutoLogLogger(formatter: MockFormatter(), sinks: [sink])
    let configuration = AutoLogConfiguration(
      outputs: [
        AutoLogOutput(
          name: "Firebase Results",
          route: .firebase,
          eventTypes: [.success]
        )
      ]
    )
    let event = AutoLogEvent(
      location: "App/AuthViewModel.swift:1:1",
      declaration: "func login()"
    )

    logger.emitStart(event: event, configuration: configuration)
    logger.emit(event: event, configuration: configuration)

    #expect(sink.events.count == 1)
    #expect(sink.events.first?.outputEventType == .success)
  }

  @Test
  func explicitRouteTagsNarrowOtherwiseGenericOutputMatching() {
    let firebaseSink = MockEventSink(route: .firebase)
    let splunkSink = MockEventSink(route: .splunk)
    let logger = AutoLogLogger(formatter: MockFormatter(), sinks: [firebaseSink, splunkSink])
    let configuration = AutoLogConfiguration(
      outputs: [
        AutoLogOutput(name: "Firebase", route: .firebase),
        AutoLogOutput(name: "Splunk", route: .splunk)
      ]
    )

    logger.emit(
      event: AutoLogEvent(
        location: "App/AuditViewModel.swift:1:1",
        declaration: "func uploadAuditTrail()",
        tags: [AutoLogRoute.firebase]
      ),
      configuration: configuration
    )

    #expect(firebaseSink.events.count == 1)
    #expect(splunkSink.events.isEmpty)
  }

  @Test
  func externalOutputsOmitParametersByDefaultAndCanAllowListThem() {
    let defaultSink = MockEventSink(route: .firebase)
    let allowListSink = MockEventSink(route: .splunk)
    let logger = AutoLogLogger(formatter: MockFormatter(), sinks: [defaultSink, allowListSink])
    let configuration = AutoLogConfiguration(
      outputs: [
        AutoLogOutput(name: "Firebase", route: .firebase),
        AutoLogOutput(
          name: "Splunk",
          route: .splunk,
          parameterPrivacy: .allowList(["userID"])
        )
      ]
    )
    let event = AutoLogEvent(
      location: "App/AuthViewModel.swift:1:1",
      declaration: "func login(userID:token:)",
      parameters: ["userID": 42, "token": "secret"]
    )

    logger.emit(event: event, configuration: configuration)

    #expect(defaultSink.events.first?.parameters.isEmpty == true)
    #expect(defaultSink.events.first?.parameterLabels.isEmpty == true)
    #expect(allowListSink.events.first?.parameters["userID"] as? Int == 42)
    #expect(allowListSink.events.first?.parameters["token"] == nil)
  }

  @Test
  func consoleOutput_reusesRenderedLineForContextSnapshot() {
    let formatter = CountingFormatter()
    let logger = AutoLogLogger(formatter: formatter)

    logger.emit(
      event: AutoLogEvent(
        location: "App/Feature.swift:1:1",
        declaration: "func refreshDashboard()"
      ),
      configuration: .default
    )

    #expect(formatter.formatCallCount == 1)
  }

  @Test
  func failureEvents_receiveRecentContextFromPreviousLogs() {
    let sink = MockEventSink(route: .splunk)
    let logger = AutoLogLogger(formatter: CompactFormatter(), sinks: [sink], errorContextLimit: 2)
    let configuration = AutoLogConfiguration(
      outputs: [
        AutoLogOutput(
          name: "Splunk",
          route: .splunk,
          eventTypes: [.interaction, .start, .failure],
          errorContextLimit: 2
        )
      ]
    )
    let interaction = AutoLogInteraction.button("Run")

    logger.emit(
      event: AutoLogEvent(
        source: interaction,
        location: "App/AsyncExamplesView.swift:10:1",
        declaration: interaction.description
      ),
      configuration: configuration
    )

    logger.emit(
      event: AutoLogEvent(
        level: LogLevel.start,
        location: "App/AsyncExamplesViewModel.swift:11:1",
        declaration: "func processPayment() async",
        tags: [AutoLogRoute.splunk]
      ),
      configuration: configuration
    )

    logger.emit(
      event: AutoLogEvent(
        location: "App/AsyncExamplesViewModel.swift:12:1",
        declaration: "func performPayment() async throws",
        result: .failure(Failure.mock),
        tags: [AutoLogRoute.splunk]
      ),
      configuration: configuration
    )

    let failure = sink.events.last
    #expect(failure?.errorContext.count == 2)
    #expect(failure?.errorContext[0].summary.contains("Run") == true)
    #expect(failure?.errorContext[1].summary.contains("processPayment() async") == true)
  }

  @Test
  func outputProfiles_filterEventsBeforeForwardingToSink() {
    let sink = MockEventSink(route: .firebase)
    let logger = AutoLogLogger(formatter: MockFormatter(), sinks: [sink])
    let configuration = AutoLogConfiguration(
      outputs: [
        AutoLogOutput(
          name: "Firebase VM Failures",
          route: .firebase,
          eventTypes: [.failure],
          typeNameFilters: ["ViewModel"]
        )
      ]
    )

    logger.emit(
      event: AutoLogEvent(
        location: "App/AuthViewModel.swift:1:1",
        declaration: "func login()",
        result: .success(())
      ),
      configuration: configuration
    )

    logger.emit(
      event: AutoLogEvent(
        location: "App/AuthService.swift:1:1",
        declaration: "func login()",
        result: .failure(Failure.mock),
        tags: [AutoLogRoute.firebase]
      ),
      configuration: configuration
    )

    logger.emit(
      event: AutoLogEvent(
        location: "App/AuthViewModel.swift:1:1",
        declaration: "func login()",
        result: .failure(Failure.mock),
        tags: [AutoLogRoute.firebase]
      ),
      configuration: configuration
    )

    #expect(sink.events.count == 1)
    #expect(sink.events.first?.location.contains("AuthViewModel") == true)
  }

  @Test
  func outputProfiles_applyTheirOwnFailureContextLimit() {
    let sink = MockEventSink(route: .splunk)
    let logger = AutoLogLogger(formatter: CompactFormatter(), sinks: [sink], errorContextLimit: 1)
    let configuration = AutoLogConfiguration(
      outputs: [
        AutoLogOutput(
          name: "Splunk Errors",
          route: .splunk,
          eventTypes: [.start, .success, .failure],
          errorContextLimit: 3
        )
      ]
    )

    logger.emit(
      event: AutoLogEvent(
        location: "App/StartView.swift:10:1",
        declaration: "Run"
      ),
      configuration: configuration
    )

    logger.emit(
      event: AutoLogEvent(
        level: LogLevel.start,
        location: "App/CheckoutViewModel.swift:11:1",
        declaration: "func processPayment() async",
        tags: [AutoLogRoute.splunk]
      ),
      configuration: configuration
    )

    logger.emit(
      event: AutoLogEvent(
        location: "App/CheckoutRepository.swift:12:1",
        declaration: "func authorize() async",
        tags: [AutoLogRoute.splunk]
      ),
      configuration: configuration
    )

    logger.emit(
      event: AutoLogEvent(
        location: "App/CheckoutViewModel.swift:13:1",
        declaration: "func processPayment() async throws",
        result: .failure(Failure.mock),
        tags: [AutoLogRoute.splunk]
      ),
      configuration: configuration
    )

    #expect(sink.events.last?.errorContext.count == 3)
  }

  @Test
  func outputProfiles_canScopeFailureContextToRecentTriggers() {
    let sink = MockEventSink(route: .splunk)
    let logger = AutoLogLogger(formatter: CompactFormatter(), sinks: [sink], errorContextLimit: 10)
    let configuration = AutoLogConfiguration(
      outputs: [
        AutoLogOutput(
          name: "Splunk Errors",
          route: .splunk,
          eventTypes: [.interaction, .start, .failure],
          errorContextLimit: 10,
          failureContextTriggerLimit: 2
        )
      ]
    )

    let olderInteraction = AutoLogInteraction.button("Old")
    logger.emit(
      event: AutoLogEvent(
        source: olderInteraction,
        location: "App/AsyncExamplesView.swift:10:1",
        declaration: olderInteraction.description,
        tags: [AutoLogRoute.splunk]
      ),
      configuration: configuration
    )

    logger.emit(
      event: AutoLogEvent(
        level: LogLevel.start,
        location: "App/AsyncExamplesViewModel.swift:11:1",
        declaration: "func olderFlow() async",
        tags: [AutoLogRoute.splunk]
      ),
      configuration: configuration
    )

    let recentInteraction = AutoLogInteraction.button("Recent")
    logger.emit(
      event: AutoLogEvent(
        source: recentInteraction,
        location: "App/AsyncExamplesView.swift:20:1",
        declaration: recentInteraction.description,
        tags: [AutoLogRoute.splunk]
      ),
      configuration: configuration
    )

    logger.emit(
      event: AutoLogEvent(
        level: LogLevel.start,
        location: "App/AsyncExamplesViewModel.swift:21:1",
        declaration: "func recentFlow() async",
        tags: [AutoLogRoute.splunk]
      ),
      configuration: configuration
    )

    logger.emit(
      event: AutoLogEvent(
        location: "App/AsyncExamplesViewModel.swift:22:1",
        declaration: "func fail() async throws",
        result: .failure(Failure.mock),
        tags: [AutoLogRoute.splunk]
      ),
      configuration: configuration
    )

    let summaries = sink.events.last?.errorContext.map(\.summary) ?? []
    #expect(summaries.count == 2)
    #expect(summaries.allSatisfy { !$0.contains("olderFlow") && !$0.contains("Old") })
    #expect(summaries.contains { $0.contains("Recent") })
    #expect(summaries.contains { $0.contains("recentFlow") })
  }

  @Test
  func outputProfileMatching_sharesConsoleRouteAndTypeFilterRules() {
    let output = AutoLogOutput(
      name: "Console ViewModel Success",
      route: .console,
      eventTypes: [.success],
      typeNameFilters: ["viewmodel"]
    )

    let matchingEvent = AutoLogEvent(
      location: "App/CheckoutViewModel.swift:13:1",
      declaration: "func processPayment() async"
    )
    let routedAwayEvent = AutoLogEvent(
      location: "App/CheckoutViewModel.swift:14:1",
      declaration: "func processPayment() async",
      tags: [AutoLogRoute.firebase]
    )
    let filteredEvent = AutoLogEvent(
      location: "App/CheckoutRepository.swift:15:1",
      declaration: "func processPayment() async"
    )

    #expect(output.matches(matchingEvent))
    #expect(!output.matches(routedAwayEvent))
    #expect(!output.matches(filteredEvent))
  }

  @Test
  func outputProfileMatching_canFilterWarningEventsSeparatelyFromSuccesses() {
    let output = AutoLogOutput(
      name: "Console Warnings",
      route: .console,
      eventTypes: [.warning]
    )

    let warningEvent = AutoLogEvent(
      level: LogLevel.warning,
      location: "App/OrderCache.swift:14:1",
      declaration: "func publishUpdate()"
    )
    let successEvent = AutoLogEvent(
      location: "App/OrderCache.swift:15:1",
      declaration: "func publishUpdate()"
    )

    #expect(output.matches(warningEvent))
    #expect(!output.matches(successEvent))
  }

  @Test
  func outputProfileMatching_normalizesTypeFiltersBeforeEmitTime() throws {
    let output = AutoLogOutput(
      name: "Console ViewModel Success",
      route: .console,
      eventTypes: [.success],
      typeNameFilters: ["  viewmodel  ", "", " service "]
    )

    #expect(output.typeNameFilters == ["viewmodel", "service"])

    let data = try JSONEncoder().encode(output)
    let decoded = try JSONDecoder().decode(AutoLogOutput.self, from: data)
    #expect(decoded.typeNameFilters == ["viewmodel", "service"])
  }

  @Test
  func outputProfileMatching_normalizesTypeFiltersAfterMutation() {
    var output = AutoLogOutput(
      name: "Console ViewModel Success",
      route: .console,
      eventTypes: [.success],
      typeNameFilters: ["repository"]
    )

    output.typeNameFilters = ["  viewmodel  ", "", " service "]

    #expect(output.typeNameFilters == ["viewmodel", "service"])

    let matchingEvent = AutoLogEvent(
      location: "App/CheckoutViewModel.swift:13:1",
      declaration: "func processPayment() async"
    )
    let blankFilterEvent = AutoLogEvent(
      location: "App/CheckoutRepository.swift:14:1",
      declaration: "func processPayment() async"
    )

    #expect(output.matches(matchingEvent))
    #expect(!output.matches(blankFilterEvent))
  }

  @Test
  func autoLogEvent_outputEventTypeReflectsInteractionStartWarningAndFailureCases() {
    let interactionSource = AutoLogInteraction.button("Pay")
    let interaction = AutoLogEvent(
      source: interactionSource,
      location: "App/CheckoutView.swift:10:1",
      declaration: interactionSource.description
    )
    let start = AutoLogEvent(
      level: LogLevel.start,
      location: "App/CheckoutViewModel.swift:11:1",
      declaration: "func processPayment() async"
    )
    let failure = AutoLogEvent(
      location: "App/CheckoutViewModel.swift:12:1",
      declaration: "func processPayment() async throws",
      result: .failure(Failure.mock)
    )
    let warning = AutoLogEvent(
      level: LogLevel.warning,
      location: "App/OrderCache.swift:13:1",
      declaration: "func publishUpdate()"
    )

    #expect(interaction.outputEventType == .interaction)
    #expect(start.outputEventType == .start)
    #expect(warning.outputEventType == .warning)
    #expect(failure.outputEventType == .failure)
    #expect(failure.inferredTypeName == "CheckoutViewModel")
  }

  @Test
  func autoLogEvent_cachesDerivedLocationAndDeclarationMetadata() {
    let event = AutoLogEvent(
      location: "App/CheckoutViewModel.swift:42:7",
      declaration: "func processPayment(amount: Decimal) async throws"
    )

    #expect(event.inferredTypeName == "CheckoutViewModel")
    #expect(event.sourceLine == "42")
    #expect(event.shortLocation == "CheckoutViewModel:42")
    #expect(event.functionName == "processPayment")
    #expect(event.hasAsyncEffect)
  }
}

extension AutoLoggerTests {
  enum Failure: Error {
    case mock
    case expectedFlow
    case iamError
    case other
  }

  // @AutoLog (no-arg) avoids the Swift compiler ICE caused by passing a non-AutoLogLogger
  // existential to @AutoLog(using:). The test uses a scoped runtime override instead.
  @AutoLog
  struct Testcase {
    func mockThrowingFunction() throws {
      throw Failure.mock
    }

    func mockAsyncThrowingFunction() async throws {
      try await Task.sleep(for: .milliseconds(100))
      throw Failure.mock
    }

    @Level(.mockError)
    func mockFunctionReturningVoidWithErrorLevelAnnotation() {

    }

    @Level("error")
    func mockFunctionReturningVoidWithStringErrorLevelAnnotation() {

    }

    @Omit("value")
    func mockGenericFunctionWithOmitSpecificParameterAnnotationReturingPassedArgument<T>(
      mock value: T
    ) -> T {
      value
    }

    @Omit(.parameters)
    func mockFunctionWithMultipleParametersAndOmitParametersAnnotation(
      _ intValue: Int,
      _ stringValue: String
    ) -> String {
      intValue.description + stringValue
    }

    @Omit(.result)
    @Tag(.mock)
    @Tag("mock-string-tag")
    func mockFunctionWitgTagAndOmitResultAnnotation() -> Bool {
      true
    }

    @Omit(.result, containing: "false")
    func mockConditionalFalseResult(flag: Bool) -> Bool {
      flag
    }

    @Omit(.error, upToCount: 1)
    func mockThrowingFunctionWithExpectedError() throws {
      throw Failure.expectedFlow
    }

    @Omit(.error, containing: ["iamerror"], upToCount: 1)
    func mockThrowingIAMStyleError() throws {
      throw Failure.iamError
    }

    @Omit(.error, containing: ["iamerror"], upToCount: 1)
    func mockThrowingOtherError() throws {
      throw Failure.other
    }

    @Omit
    var isCreating: Bool {
      false
    }
  }
}

private final class MockEventSink: AutoLogEventSink, @unchecked Sendable {
  let route: AutoLogRoute
  var events: [AutoLogEvent] = []

  init(route: AutoLogRoute) {
    self.route = route
  }

  func emit(event: AutoLogEvent, configuration: AutoLogConfiguration) {
    events.append(event)
  }
}

private struct MockFormatter: AutoLogFormatter {
  func format(event: AutoLogEvent, configuration: AutoLogConfiguration) -> String {
    "formatted"
  }
}

private final class CountingFormatter: AutoLogFormatter, @unchecked Sendable {
  private let formatCount = Mutex(0)

  var formatCallCount: Int {
    formatCount.withLock { $0 }
  }

  func format(event: AutoLogEvent, configuration: AutoLogConfiguration) -> String {
    formatCount.withLock { count in
      count += 1
    }
    return "formatted"
  }
}
