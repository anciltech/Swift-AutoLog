import AutoLog
import Synchronization
import Testing

@Suite(.serialized)
struct AutoLoggerTests {
  static let mock = MockLogger()

  @Test
  func whenLoggerAttachedToType_expectedToCaptureAllEvent() async throws {
    // Workaround: @Logged(using: MockLogger) triggers a Swift compiler ICE due to
    // existential boxing in macro argument type-checking (ResolveMacroRequest crash).
    // Use @Logged (no-arg) with a temporary global-logger override instead.
    let prevLogger = AutoLogSource.logger
    let prevEmitStart = AutoLogSettingsStorage.emitStartEvents
    AutoLogSource.logger = Self.mock
    AutoLogSettingsStorage.emitStartEvents = false
    defer {
      AutoLogSource.logger = prevLogger
      AutoLogSettingsStorage.emitStartEvents = prevEmitStart
    }

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
  }
}

extension AutoLoggerTests {
  enum Failure: Error {
    case mock
  }

  // @Logged (no-arg) avoids the Swift compiler ICE caused by passing a non-AutoLogLogger
  // existential to @Logged(using:). The test overrides AutoLogSource.logger instead.
  @Logged
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
  }
}
