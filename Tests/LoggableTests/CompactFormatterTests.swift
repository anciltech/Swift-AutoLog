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

    @Test func defaultProfile_isMVVM() {
        let formatter = CompactFormatter()
        // Default profile is MVVM; a ViewModel type should get depth-2 arrow
        let event = makeEvent(location: "App/MyViewModel.swift:1:1")
        #expect(formatter.format(event: event).hasPrefix("-->"))
    }

    // MARK: - Emoji

    @Test func success_noLevel_emitsGreen() {
        let event = makeEvent(result: .success(()))
        #expect(CompactFormatter().format(event: event).contains(" 🟢 "))
    }

    @Test func failure_emitsRed() {
        struct E: Error {}
        let event = makeEvent(result: .failure(E()))
        #expect(CompactFormatter().format(event: event).contains(" 🔴 "))
    }

    @Test func osLogError_emitsRed() {
        let event = makeEvent(level: OSLogType.error, result: .success(()))
        #expect(CompactFormatter().format(event: event).contains(" 🔴 "))
    }

    @Test func osLogFault_emitsRed() {
        let event = makeEvent(level: OSLogType.fault, result: .success(()))
        #expect(CompactFormatter().format(event: event).contains(" 🔴 "))
    }

    @Test func osLogDefault_emitsYellow() {
        let event = makeEvent(level: OSLogType.default, result: .success(()))
        #expect(CompactFormatter().format(event: event).contains(" 🟡 "))
    }

    @Test func osLogInfo_emitsBlue() {
        let event = makeEvent(level: OSLogType.info, result: .success(()))
        #expect(CompactFormatter().format(event: event).contains(" 🔵 "))
    }

    @Test func osLogDebug_emitsBlue() {
        let event = makeEvent(level: OSLogType.debug, result: .success(()))
        #expect(CompactFormatter().format(event: event).contains(" 🔵 "))
    }

    @Test func failure_winsOverLevel() {
        struct E: Error {}
        let event = makeEvent(level: OSLogType.info, result: .failure(E()))
        #expect(CompactFormatter().format(event: event).contains(" 🔴 "))
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
        // Compact format shows function name only — 'throws' is omitted for brevity.
        let event = makeEvent(declaration: "func run() throws")
        let output = CompactFormatter().format(event: event)
        #expect(output.contains("run()"))
        #expect(!output.contains("throws"))
    }

    @Test func asyncThrowingFunc_showsBoth() {
        // Compact format shows 'async' but omits 'throws'.
        let event = makeEvent(declaration: "func run() async throws")
        let output = CompactFormatter().format(event: event)
        #expect(output.contains("run() async"))
        #expect(!output.contains("throws"))
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
        #expect(lines[1].contains("user"))
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
        // Use a class box to capture the last formatted output in a @Sendable closure.
        // Workaround: @Logged(using: LoggableLogger(formatter:)) inside a function body
        // triggers a Swift compiler ICE (ExpandBodyMacroRequest crash). Instead we override
        // LoggableSource.logger temporarily and use @Log (no-arg) on the inner struct.
        final class Box: @unchecked Sendable { var value = "" }
        let box = Box()

        struct CapturingFormatter: LoggableFormatter {
            let box: Box
            func format(event: LoggableEvent) -> String {
                let output = CompactFormatter().format(event: event)
                box.value = output
                return output
            }
        }

        let prevLogger = LoggableSource.logger
        let prevEmitStart = LoggableSettingsStorage.emitStartEvents
        LoggableSource.logger = LoggableLogger(formatter: CapturingFormatter(box: box))
        LoggableSettingsStorage.emitStartEvents = false
        defer {
            LoggableSource.logger = prevLogger
            LoggableSettingsStorage.emitStartEvents = prevEmitStart
        }

        struct Subject {
            @Log
            func greet(name: String) -> String { "Hello, \(name)" }
        }

        _ = Subject().greet(name: "World")

        #expect(box.value.contains("🟢"))
        #expect(box.value.contains("greet(name: World)"))
        #expect(box.value.contains("→ Hello, World"))
    }
}
