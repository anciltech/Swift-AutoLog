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
