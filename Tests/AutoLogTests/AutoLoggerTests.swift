import AutoLog
import Synchronization
import Testing

@Suite(.serialized)
struct AutoLoggerTests {
  static let mock = MockLogger()

  @Test
  func whenLoggerAttachedToType_expectedToCaptureAllEvent() async throws {
    // Workaround: @AutoLog(using: MockLogger) triggers a Swift compiler ICE due to
    // existential boxing in macro argument type-checking (ResolveMacroRequest crash).
    // Use @AutoLog (no-arg) with a scoped runtime override instead.
    let runtime = AutoLogRuntime(
      logger: Self.mock,
      configuration: AutoLogConfiguration(emitStartEvents: false)
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
  func failureEvents_receiveRecentContextFromPreviousLogs() {
    let sink = MockEventSink(route: .splunk)
    let logger = AutoLogLogger(formatter: CompactFormatter(), sinks: [sink], errorContextLimit: 2)
    let configuration = AutoLogConfiguration(
      outputs: [
        AutoLogOutput(
          name: "Splunk",
          route: .splunk,
          eventTypes: [.start, .failure],
          errorContextLimit: 2
        )
      ]
    )

    logger.emit(
      event: AutoLogEvent(
        location: "App/AsyncExamplesView.swift:10:1",
        declaration: "Run"
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
    #expect(failure?.errorContext[0].summary.contains("Run()") == true)
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
          eventTypes: [.failure],
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
  func autoLogEvent_outputEventTypeReflectsInteractionStartAndFailureCases() {
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

    #expect(interaction.outputEventType == .interaction)
    #expect(start.outputEventType == .start)
    #expect(failure.outputEventType == .failure)
    #expect(failure.inferredTypeName == "CheckoutViewModel")
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
