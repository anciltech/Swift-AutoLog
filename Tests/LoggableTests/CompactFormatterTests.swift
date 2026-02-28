import Loggable
import Testing

@Suite
struct CompactFormatterTests {

    func makeEvent(
        level: (any Levelable)? = nil,
        location: String = "App/MyViewModel.swift:10:5",
        declaration: String = "func doSomething()",
        parameters: [String: Any] = [:],
        result: Result<Any, any Error> = .success(()),
        tags: [any Taggable] = []
    ) -> LoggableEvent {
        LoggableEvent(
            level: level,
            location: location,
            declaration: declaration,
            parameters: parameters,
            result: result,
            tags: tags
        )
    }

    // MARK: - Instantiation

    @Test func compactFormatter_exists() {
        let _ = CompactFormatter()
        let _ = CompactFormatter(profile: .mvvm)
    }

    // MARK: - Emoji

    @Test func success_noLevel_emitsGreen() {
        let event = makeEvent(result: .success(()))
        #expect(CompactFormatter().format(event: event).hasPrefix("-> 🟢"))
    }

    @Test func failure_emitsRed() {
        struct E: Error {}
        let event = makeEvent(result: .failure(E()))
        #expect(CompactFormatter().format(event: event).hasPrefix("-> 🔴"))
    }

    @Test func osLogError_emitsRed() {
        let event = makeEvent(level: OSLogType.error, result: .success(()))
        #expect(CompactFormatter().format(event: event).hasPrefix("-> 🔴"))
    }

    @Test func osLogFault_emitsRed() {
        let event = makeEvent(level: OSLogType.fault, result: .success(()))
        #expect(CompactFormatter().format(event: event).hasPrefix("-> 🔴"))
    }

    @Test func osLogDefault_emitsYellow() {
        let event = makeEvent(level: OSLogType.default, result: .success(()))
        #expect(CompactFormatter().format(event: event).hasPrefix("-> 🟡"))
    }

    @Test func osLogInfo_emitsBlue() {
        let event = makeEvent(level: OSLogType.info, result: .success(()))
        #expect(CompactFormatter().format(event: event).hasPrefix("-> 🔵"))
    }

    @Test func osLogDebug_emitsBlue() {
        let event = makeEvent(level: OSLogType.debug, result: .success(()))
        #expect(CompactFormatter().format(event: event).hasPrefix("-> 🔵"))
    }

    @Test func failure_winsOverLevel() {
        struct E: Error {}
        let event = makeEvent(level: OSLogType.info, result: .failure(E()))
        #expect(CompactFormatter().format(event: event).hasPrefix("-> 🔴"))
    }

    // MARK: - Type name + depth arrow

    @Test func typeName_extractedFromLocation() {
        let event = makeEvent(location: "App/LoggingDemoViewModel.swift:79:5")
        let output = CompactFormatter().format(event: event)
        #expect(output.contains("LoggingDemoViewModel."))
    }

    @Test func typeName_withoutPath_stillWorks() {
        let event = makeEvent(location: "SimpleView.swift:10:5")
        let output = CompactFormatter().format(event: event)
        #expect(output.contains("SimpleView."))
    }

    @Test func viewModel_getsDoubleArrow() {
        let event = makeEvent(location: "App/MyViewModel.swift:1:1")
        #expect(CompactFormatter(profile: .mvvm).format(event: event).hasPrefix("-->"))
    }

    @Test func view_getsSingleArrow() {
        let event = makeEvent(location: "App/ContentView.swift:1:1")
        let output = CompactFormatter(profile: .mvvm).format(event: event)
        #expect(output.hasPrefix("->"))
        #expect(!output.hasPrefix("-->"))
    }

    // MARK: - Function name + parameters

    @Test func funcName_extractedFromDeclaration() {
        let event = makeEvent(declaration: "func runAsyncScenario() async")
        #expect(CompactFormatter().format(event: event).contains("runAsyncScenario()"))
    }

    @Test func parameters_shownInSignature() {
        let event = makeEvent(
            declaration: "func fetchUser(id: Int) async throws -> String",
            parameters: ["id": 1]
        )
        #expect(CompactFormatter().format(event: event).contains("fetchUser(id: 1)"))
    }

    @Test func emptyParameters_showEmptyParens() {
        let event = makeEvent(declaration: "func doSomething()")
        #expect(CompactFormatter().format(event: event).contains("doSomething()"))
    }

    // MARK: - Effect specifiers

    @Test func asyncFunc_showsAsyncSuffix() {
        let event = makeEvent(declaration: "func run() async")
        #expect(CompactFormatter().format(event: event).contains("run() async"))
    }

    @Test func throwingFunc_showsThrowsSuffix() {
        let event = makeEvent(declaration: "func run() throws")
        #expect(CompactFormatter().format(event: event).contains("run() throws"))
    }

    @Test func asyncThrowingFunc_showsBoth() {
        let event = makeEvent(declaration: "func run() async throws")
        #expect(CompactFormatter().format(event: event).contains("run() async throws"))
    }

    // MARK: - Return value

    @Test func successWithReturnValue_showsInlineArrow() {
        let event = makeEvent(
            declaration: "func fetchUser(id: Int) async throws -> String",
            parameters: ["id": 1],
            result: .success("User1")
        )
        #expect(CompactFormatter().format(event: event).contains("→ User1"))
    }

    @Test func successWithVoid_doesNotShowArrow() {
        let event = makeEvent(result: .success(()))
        #expect(!CompactFormatter().format(event: event).contains("→"))
    }

    // MARK: - Second line

    @Test func failure_showsErrorOnSecondLine() {
        enum NetworkError: Error { case notFound }
        let event = makeEvent(result: .failure(NetworkError.notFound))
        let output = CompactFormatter().format(event: event)
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 2)
        #expect(lines[1].contains("↳"))
        #expect(lines[1].contains("notFound"))
        #expect(lines[1].contains("NetworkError"))
    }

    @Test func tags_shownOnSecondLine() {
        let event = makeEvent(
            result: .success(()),
            tags: ["update", "user"] as [any Taggable]
        )
        let output = CompactFormatter().format(event: event)
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 2)
        #expect(lines[1].contains("↳"))
        #expect(lines[1].contains("update"))
    }

    @Test func noTagsNoError_noSecondLine() {
        let event = makeEvent(result: .success(()))
        #expect(!CompactFormatter().format(event: event).contains("\n"))
    }
}

// MARK: - Integration

@Suite(.serialized)
struct CompactFormatterIntegrationTests {

    @Test func loggedMacro_emitsCompactFormat() {
        var captured: String = ""

        struct CapturingFormatter: LoggableFormatter {
            let capture: @Sendable (String) -> Void
            func format(event: LoggableEvent) -> String {
                let output = CompactFormatter().format(event: event)
                capture(output)
                return output
            }
        }

        @Logged(using: LoggableLogger(formatter: CapturingFormatter { captured = $0 }))
        struct Subject {
            func greet(name: String) -> String { "Hello, \(name)" }
        }

        _ = Subject().greet(name: "World")

        #expect(captured.contains("🟢"))
        #expect(captured.contains("greet(name: World)"))
        #expect(captured.contains("→ Hello, World"))
    }
}
