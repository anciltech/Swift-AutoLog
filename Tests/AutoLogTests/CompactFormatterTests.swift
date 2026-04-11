import AutoLog
import Foundation
import Testing

@Suite
struct CompactFormatterTests {
    let configuration = AutoLogConfiguration.default

    func makeEvent(
        level: (any Levelable)? = nil,
        location: String = "App/MyViewModel.swift:10:5",
        declaration: String = "func doSomething()",
        parameters: [String: Any] = [:],
        result: Result<Any, any Error> = .success(()),
        tags: [any Taggable] = []
    ) -> AutoLogEvent {
        AutoLogEvent(
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
        let output = formatter.format(event: event, configuration: configuration)
        #expect(output.contains("│ bg"))
        #expect(output.contains("-->"))
    }

    // MARK: - Emoji

    @Test func success_noLevel_emitsGreen() {
        let event = makeEvent(result: .success(()))
        #expect(CompactFormatter().format(event: event, configuration: configuration).contains(" 🟢 "))
    }

    @Test func failure_emitsRed() {
        struct E: Error {}
        let event = makeEvent(result: .failure(E()))
        #expect(CompactFormatter().format(event: event, configuration: configuration).contains(" 🔴 "))
    }

    @Test func osLogError_emitsRed() {
        let event = makeEvent(level: OSLogType.error, result: .success(()))
        #expect(CompactFormatter().format(event: event, configuration: configuration).contains(" 🔴 "))
    }

    @Test func osLogFault_emitsRed() {
        let event = makeEvent(level: OSLogType.fault, result: .success(()))
        #expect(CompactFormatter().format(event: event, configuration: configuration).contains(" 🔴 "))
    }

    @Test func osLogDefault_emitsYellow() {
        let event = makeEvent(level: OSLogType.default, result: .success(()))
        #expect(CompactFormatter().format(event: event, configuration: configuration).contains(" 🟡 "))
    }

    @Test func osLogInfo_emitsBlue() {
        let event = makeEvent(level: OSLogType.info, result: .success(()))
        #expect(CompactFormatter().format(event: event, configuration: configuration).contains(" 🔵 "))
    }

    @Test func osLogDebug_emitsBlue() {
        let event = makeEvent(level: OSLogType.debug, result: .success(()))
        #expect(CompactFormatter().format(event: event, configuration: configuration).contains(" 🔵 "))
    }

    @Test func failure_winsOverLevel() {
        struct E: Error {}
        let event = makeEvent(level: OSLogType.info, result: .failure(E()))
        #expect(CompactFormatter().format(event: event, configuration: configuration).contains(" 🔴 "))
    }

    // MARK: - Type name + depth arrow

    @Test func typeName_extractedFromLocation() {
        let event = makeEvent(location: "App/LoggingDemoViewModel.swift:79:5")
        let output = CompactFormatter().format(event: event, configuration: configuration)
        #expect(output.contains("LoggingDemoViewModel."))
    }

    @Test func typeName_withoutPath_stillWorks() {
        let event = makeEvent(location: "SimpleView.swift:10:5")
        let output = CompactFormatter().format(event: event, configuration: configuration)
        #expect(output.contains("SimpleView."))
    }

    @Test func viewModel_getsDoubleArrow() {
        let event = makeEvent(location: "App/MyViewModel.swift:1:1")
        #expect(CompactFormatter(profile: .mvvm).format(event: event, configuration: configuration).contains("-->"))
    }

    @Test func view_getsSingleArrow() {
        let event = makeEvent(location: "App/ContentView.swift:1:1")
        let output = CompactFormatter(profile: .mvvm).format(event: event, configuration: configuration)
        #expect(output.contains("->"))
        #expect(!output.contains("-->"))
    }

    @Test func lineNumberElement_appendsSourceLineSuffix() {
        let event = makeEvent(
            location: "App/MyViewModel.swift:42:5",
            declaration: "func refresh()"
        )
        let config = AutoLogConfiguration(
            logFormat: LogFormat(mainLine: [
                .depthArrow,
                .statusEmoji,
                .typeName,
                .dotSeparator,
                .functionName,
                .lineNumber,
            ])
        )

        let output = CompactFormatter().format(event: event, configuration: config)
        #expect(output.contains("MyViewModel.refresh:42"))
    }

    // MARK: - Function name + parameters

    @Test func funcName_extractedFromDeclaration() {
        let event = makeEvent(declaration: "func runAsyncScenario() async")
        #expect(CompactFormatter().format(event: event, configuration: configuration).contains("runAsyncScenario()"))
    }

    @Test func parameters_shownInSignature() {
        let event = makeEvent(
            declaration: "func fetchUser(id: Int) async throws -> String",
            parameters: ["id": 1]
        )
        #expect(CompactFormatter().format(event: event, configuration: configuration).contains("fetchUser(id: 1)"))
    }

    @Test func identifiableParameter_prefersShortIDSummary() {
        final class Frame {
            let id: UUID

            init(id: UUID) {
                self.id = id
            }
        }

        let event = makeEvent(
            declaration: "func isHovered(frame: Frame) -> Bool",
            parameters: ["frame": Frame(id: UUID(uuidString: "12345678-1234-1234-1234-123456782341")!)],
            result: .success(false)
        )

        #expect(CompactFormatter().format(event: event, configuration: configuration).contains("isHovered(frame: Frame.id: ...2341)"))
    }

    @Test func identifierParameter_prefersShortIDSummary() {
        final class Session {
            let identifier: String

            init(identifier: String) {
                self.identifier = identifier
            }
        }

        let event = makeEvent(
            declaration: "func attach(session: Session)",
            parameters: ["session": Session(identifier: "session-abcdef12")]
        )

        #expect(CompactFormatter().format(event: event, configuration: configuration).contains("attach(session: Session.identifier: ...ef12)"))
    }

    @Test func shortTypeDescriptionStillPrefersShortIDSummary() {
        final class Frame: CustomStringConvertible {
            let id: UUID

            init(id: UUID) {
                self.id = id
            }

            var description: String { "Frame" }
        }

        let event = makeEvent(
            declaration: "func isSelected(frame: Frame) -> Bool",
            parameters: ["frame": Frame(id: UUID(uuidString: "12345678-1234-1234-1234-123456782341")!)],
            result: .success(false)
        )

        #expect(CompactFormatter().format(event: event, configuration: configuration).contains("isSelected(frame: Frame.id: ...2341)"))
    }

    @Test func wrappedUnderscoredIdentifierPrefersShortIDSummary() {
        struct IDBox {
            let rawValue: UUID
        }

        final class Frame: CustomStringConvertible {
            let _id: IDBox

            init(id: UUID) {
                self._id = IDBox(rawValue: id)
            }

            var description: String { "Frame" }
        }

        let event = makeEvent(
            declaration: "func isDragging(frame: Frame) -> Bool",
            parameters: ["frame": Frame(id: UUID(uuidString: "89CA345B-CE1D-43F5-B5BE-3F4D2C370BD8")!)],
            result: .success(false)
        )

        #expect(CompactFormatter().format(event: event, configuration: configuration).contains("isDragging(frame: Frame.id: ...0bd8)"))
    }

    @Test func descriptiveValue_keepsItsDefaultDescription() {
        struct Frame {
            let id: UUID
            let name: String
        }

        let event = makeEvent(
            declaration: "func inspect(frame: Frame)",
            parameters: ["frame": Frame(id: UUID(uuidString: "12345678-1234-1234-1234-123456782341")!, name: "Hero")]
        )

        let output = CompactFormatter().format(event: event, configuration: configuration)
        #expect(output.contains("inspect(frame: Frame(id:"))
        #expect(!output.contains("Frame.id: ...2341"))
    }

    @Test func metatypeParameter_stripsModuleQualification() {
        let event = makeEvent(
            declaration: "func register(type: Any.Type)",
            parameters: ["type": Date.self]
        )

        #expect(CompactFormatter().format(event: event, configuration: configuration).contains("register(type: Date)"))
    }

    @Test func emptyParameters_showEmptyParens() {
        let event = makeEvent(declaration: "func doSomething()")
        #expect(CompactFormatter().format(event: event, configuration: configuration).contains("doSomething()"))
    }

    // MARK: - Effect specifiers

    @Test func asyncFunc_showsAsyncSuffix() {
        let event = makeEvent(declaration: "func run() async")
        #expect(CompactFormatter().format(event: event, configuration: configuration).contains("run() async"))
    }

    @Test func throwingFunc_showsThrowsSuffix() {
        // Compact format shows function name only — 'throws' is omitted for brevity.
        let event = makeEvent(declaration: "func run() throws")
        let output = CompactFormatter().format(event: event, configuration: configuration)
        #expect(output.contains("run()"))
        #expect(!output.contains("throws"))
    }

    @Test func asyncThrowingFunc_showsBoth() {
        // Compact format shows 'async' but omits 'throws'.
        let event = makeEvent(declaration: "func run() async throws")
        let output = CompactFormatter().format(event: event, configuration: configuration)
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
        #expect(CompactFormatter().format(event: event, configuration: configuration).contains("→ User1"))
    }

    @Test func successWithVoid_doesNotShowArrow() {
        let event = makeEvent(result: .success(()))
        #expect(!CompactFormatter().format(event: event, configuration: configuration).contains("→"))
    }

    // MARK: - Second line

    @Test func failure_showsErrorInlineOnMainLine() {
        enum NetworkError: Error { case notFound }
        let event = makeEvent(result: .failure(NetworkError.notFound))
        let output = CompactFormatter().format(event: event, configuration: configuration)
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 1)
        #expect(lines[0].contains("notFound"))
        #expect(lines[0].contains("NetworkError"))
    }

    @Test func failure_showsRecentContextAboveError() {
        enum NetworkError: Error { case notFound }
        var event = makeEvent(result: .failure(NetworkError.notFound))
        event.errorContext = [
            AutoLogErrorContextEntry(summary: "-> 👆🏼 Run [AsyncExamplesView:42]"),
            AutoLogErrorContextEntry(summary: "--> 🔵 AsyncExamplesViewModel.processPayment() async"),
        ]

        let output = CompactFormatter().format(event: event, configuration: configuration)
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false)

        #expect(lines.count == 5)
        #expect(lines[0].contains("notFound"))
        #expect(lines[1].contains("context"))
        #expect(lines[2].contains("Run [AsyncExamplesView:42]"))
        #expect(lines[3].contains("processPayment() async"))
        #expect(lines[4].contains("─"))
    }

    @Test func tags_shownOnSecondLine() {
        let event = makeEvent(
            result: .success(()),
            tags: ["update", "user"] as [any Taggable]
        )
        let output = CompactFormatter().format(event: event, configuration: configuration)
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 2)
        #expect(lines[1].contains("╰─"))
        #expect(lines[1].contains("update"))
        #expect(lines[1].contains("user"))
    }

    @Test func routingTags_areHiddenFromFormattedTagLine() {
        let event = makeEvent(
            result: .success(()),
            tags: ["update", AutoLogRoute.splunk] as [any Taggable]
        )
        let output = CompactFormatter().format(event: event, configuration: configuration)
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 2)
        #expect(lines[1].contains("update"))
        #expect(!lines[1].contains("splunk"))
    }

    @Test func branchDecisions_showOnSecondLineWhenNoEarlyExit() {
        var event = makeEvent(result: .success(()))
        event.recordBranchDecision(kind: .if, condition: "isVisible")
        event.recordBranchDecision(kind: .else, condition: "isVisible")

        let output = CompactFormatter().format(event: event, configuration: configuration)
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 2)
        #expect(lines[1].contains("branch path"))
        #expect(lines[1].contains("if branch condition=isVisible"))
        #expect(lines[1].contains("else branch condition=isVisible"))
    }

    @Test func earlyExit_showsOnSecondLine() {
        var event = makeEvent(result: .success(()))
        event.setEarlyExit(kind: .guard, intent: .expected, condition: "!count > 0", message: "empty list")

        let output = CompactFormatter().format(event: event, configuration: configuration)
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 2)
        #expect(lines[1].contains("↘️"))
        #expect(lines[1].contains("!count > 0"))
        #expect(lines[1].contains("expected"))
        #expect(lines[1].contains("•"))
        #expect(lines[1].contains("empty list"))
    }

    @Test func earlyExit_takesPriorityOverBranchDecisions() {
        var event = makeEvent(result: .success(()))
        event.setEarlyExit(kind: .if, intent: .optimize, condition: "isCached", message: nil)
        event.recordBranchDecision(kind: .if, condition: "isCached")

        let output = CompactFormatter().format(event: event, configuration: configuration)
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 2)
        #expect(lines[1].contains("↘️"))
        #expect(lines[1].contains("optimize"))
        #expect(!lines[1].contains("branch path"))
    }

    @Test func earlyExit_hidesUnknownIntent() {
        var event = makeEvent(result: .success(()))
        event.setEarlyExit(kind: .if, intent: .unknown, condition: "isCached", message: "cache hit")

        let output = CompactFormatter().format(event: event, configuration: configuration)
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 2)
        #expect(lines[1].contains("↘️ isCached"))
        #expect(!lines[1].contains("unknown"))
        #expect(lines[1].contains("cache hit"))
    }

    @Test func noTagsNoError_noSecondLine() {
        let event = makeEvent(result: .success(()))
        #expect(!CompactFormatter().format(event: event, configuration: configuration).contains("\n"))
    }
}

// MARK: - LogFormat element toggling

@Suite
struct LogFormatElementToggleTests {
    let configuration = AutoLogConfiguration.default

    func makeEvent(
        location: String = "App/MyViewModel.swift:10:5",
        declaration: String = "func fetchData(id: Int) async throws -> String",
        parameters: [String: Any] = ["id": 42],
        result: Result<Any, any Error> = .success("hello")
    ) -> AutoLogEvent {
        AutoLogEvent(
            location: location,
            declaration: declaration,
            parameters: parameters,
            result: result
        )
    }

    @Test func returnValue_suppressedWhenElementRemoved() {
        var format = LogFormat.default
        format.mainLine.removeAll { $0 == .returnValue }
        let formatter = CompactFormatter(profile: .mvvm, format: format)
        let event = makeEvent()
        let output = formatter.format(event: event, configuration: configuration)
        #expect(!output.contains("→"))
        #expect(output.contains("fetchData(id: 42)"))
    }

    @Test func returnValue_visibleByDefault() {
        let formatter = CompactFormatter(profile: .mvvm)
        let event = makeEvent()
        let output = formatter.format(event: event, configuration: configuration)
        #expect(output.contains("→ hello"))
    }

    // MARK: - Trace path (SourceContext events — Button.log / Toggle.log)

    func makeTraceEvent(
        location: String = "App/MyViewModel.swift:10:5",
        declaration: String = "func fetchData(id: Int) async -> String",
        parameters: [String: Any] = ["id": 42],
        result: Result<Any, any Error> = .success("traced-result")
    ) -> AutoLogEvent {
        let source = SourceContext(
            source: InteractionSource.button("Run"),
            location: "App/MyView.swift:10:5"
        )
        return AutoLogEvent(
            source: source,
            location: location,
            declaration: declaration,
            parameters: parameters,
            result: result
        )
    }

    @Test func traceEvent_returnValue_suppressedWhenElementRemoved() {
        var format = LogFormat.default
        format.mainLine.removeAll { $0 == .returnValue }
        let formatter = CompactFormatter(profile: .mvvm, format: format)
        let event = makeTraceEvent()
        let output = formatter.format(event: event, configuration: configuration)
        #expect(!output.contains("→ traced-result"))
        #expect(output.contains("fetchData(id: 42)"))
    }

    @Test func traceEvent_returnValue_visibleByDefault() {
        let formatter = CompactFormatter(profile: .mvvm)
        let event = makeTraceEvent()
        let output = formatter.format(event: event, configuration: configuration)
        #expect(output.contains("→ traced-result"))
    }

    @Test func traceEvent_returnValue_suppressedViaConfigurationLogFormat() {
        var format = LogFormat.default
        format.mainLine.removeAll { $0 == .returnValue }
        let configWithoutReturn = AutoLogConfiguration(logFormat: format)
        // No init-time format override — the formatter reads configuration.logFormat
        let formatter = CompactFormatter(profile: .mvvm)
        let event = makeTraceEvent()
        let output = formatter.format(event: event, configuration: configWithoutReturn)
        #expect(!output.contains("→ traced-result"))
    }

    @Test func traceEvent_effectSpecifiers_suppressedWhenElementRemoved() {
        var format = LogFormat.default
        format.mainLine.removeAll { $0 == .effectSpecifiers }
        let formatter = CompactFormatter(profile: .mvvm, format: format)
        let event = makeTraceEvent()
        let output = formatter.format(event: event, configuration: configuration)
        #expect(!output.contains(" async"))
    }

    @Test func effectSpecifiers_visibleByDefault() {
        let formatter = CompactFormatter(profile: .mvvm)
        let event = makeEvent(declaration: "func fetchData(id: Int) async -> String")
        let output = formatter.format(event: event, configuration: configuration)
        #expect(output.contains(" async"))
    }

    @Test func traceEvent_effectSpecifiers_visibleByDefault() {
        let formatter = CompactFormatter(profile: .mvvm)
        let event = makeTraceEvent()
        let output = formatter.format(event: event, configuration: configuration)
        #expect(output.contains(" async"))
    }

    @Test func effectSpecifiers_suppressedViaConfigurationLogFormat() {
        var format = LogFormat.default
        format.mainLine.removeAll { $0 == .effectSpecifiers }
        let configWithoutAsync = AutoLogConfiguration(logFormat: format)
        let formatter = CompactFormatter(profile: .mvvm)
        let event = makeEvent(declaration: "func fetchData(id: Int) async -> String")
        let output = formatter.format(event: event, configuration: configWithoutAsync)
        #expect(!output.contains(" async"))
    }

    @Test func traceEvent_effectSpecifiers_suppressedViaConfigurationLogFormat() {
        var format = LogFormat.default
        format.mainLine.removeAll { $0 == .effectSpecifiers }
        let configWithoutAsync = AutoLogConfiguration(logFormat: format)
        let formatter = CompactFormatter(profile: .mvvm)
        let event = makeTraceEvent()
        let output = formatter.format(event: event, configuration: configWithoutAsync)
        #expect(!output.contains(" async"))
    }

    @Test func typeName_suppressedWhenElementRemoved() {
        var format = LogFormat.default
        format.mainLine.removeAll { $0 == .typeName || $0 == .dotSeparator }
        let formatter = CompactFormatter(profile: .mvvm, format: format)
        let event = makeEvent()
        let output = formatter.format(event: event, configuration: configuration)
        #expect(!output.contains("MyViewModel"))
        #expect(output.contains("fetchData(id: 42)"))
    }

    @Test func typeName_suppressedViaConfigurationLogFormat() {
        var format = LogFormat.default
        format.mainLine.removeAll { $0 == .typeName || $0 == .dotSeparator }
        let configWithoutTypeName = AutoLogConfiguration(logFormat: format)
        let formatter = CompactFormatter(profile: .mvvm)
        let event = makeEvent()
        let output = formatter.format(event: event, configuration: configWithoutTypeName)
        #expect(!output.contains("MyViewModel"))
        #expect(output.contains("fetchData(id: 42)"))
    }

    @Test func traceEvent_typeName_suppressedViaConfigurationLogFormat() {
        var format = LogFormat.default
        format.mainLine.removeAll { $0 == .typeName || $0 == .dotSeparator }
        let configWithoutTypeName = AutoLogConfiguration(logFormat: format)
        let formatter = CompactFormatter(profile: .mvvm)
        let event = makeTraceEvent()
        let output = formatter.format(event: event, configuration: configWithoutTypeName)
        #expect(!output.contains("MyViewModel"))
        #expect(output.contains("fetchData(id: 42)"))
    }

    @Test func effectSpecifiers_suppressedWhenElementRemoved() {
        var format = LogFormat.default
        format.mainLine.removeAll { $0 == .effectSpecifiers }
        let formatter = CompactFormatter(profile: .mvvm, format: format)
        let event = makeEvent()
        let output = formatter.format(event: event, configuration: configuration)
        #expect(!output.contains(" async"))
    }

    @Test func depthArrow_suppressedWhenElementRemoved() {
        var format = LogFormat.default
        format.mainLine.removeAll { $0 == .depthArrow }
        let formatter = CompactFormatter(profile: .mvvm, format: format)
        let event = makeEvent()
        let output = formatter.format(event: event, configuration: configuration)
        #expect(!output.hasPrefix("->"))
        #expect(!output.hasPrefix("-->"))
        #expect(output.contains("fetchData"))
    }

    @Test func depthArrow_suppressedViaConfigurationLogFormat() {
        var format = LogFormat.default
        format.mainLine.removeAll { $0 == .depthArrow }
        let configWithoutArrow = AutoLogConfiguration(logFormat: format)
        let formatter = CompactFormatter(profile: .mvvm)
        let event = makeEvent()
        let output = formatter.format(event: event, configuration: configWithoutArrow)
        #expect(!output.hasPrefix("->"))
        #expect(output.contains("fetchData"))
    }

    @Test func statusEmoji_suppressedWhenElementRemoved() {
        var format = LogFormat.default
        format.mainLine.removeAll { $0 == .statusEmoji }
        let formatter = CompactFormatter(profile: .mvvm, format: format)
        let event = makeEvent()
        let output = formatter.format(event: event, configuration: configuration)
        #expect(!output.contains("🟢"))
        #expect(!output.contains("🔴"))
        #expect(output.contains("fetchData"))
    }

    @Test func statusEmoji_suppressedViaConfigurationLogFormat() {
        var format = LogFormat.default
        format.mainLine.removeAll { $0 == .statusEmoji }
        let configWithoutEmoji = AutoLogConfiguration(logFormat: format)
        let formatter = CompactFormatter(profile: .mvvm)
        let event = makeEvent()
        let output = formatter.format(event: event, configuration: configWithoutEmoji)
        #expect(!output.contains("🟢"))
        #expect(output.contains("fetchData"))
    }

    @Test func lineNumber_appearsWhenElementAdded() {
        var format = LogFormat.default
        // Insert lineNumber after the typeName
        if let idx = format.mainLine.firstIndex(of: .dotSeparator) {
            format.mainLine.insert(.lineNumber, at: idx)
        }
        let formatter = CompactFormatter(profile: .mvvm, format: format)
        let event = makeEvent(location: "App/MyViewModel.swift:42:5")
        let output = formatter.format(event: event, configuration: configuration)
        #expect(output.contains(":42"))
    }

    @Test func traceEvent_lineNumber_appearsWhenElementAdded() {
        var format = LogFormat.default
        if let idx = format.mainLine.firstIndex(of: .timing) {
            format.mainLine.insert(.lineNumber, at: idx)
        } else {
            format.mainLine.append(.lineNumber)
        }

        let formatter = CompactFormatter(profile: .mvvm, format: format)
        let event = makeTraceEvent(location: "App/MyViewModel.swift:42:5")
        let output = formatter.format(event: event, configuration: configuration)
        #expect(output.contains(":42"))
        #expect(output.contains("fetchData(id: 42) async → traced-result"))
    }

    @Test func parameters_suppressedWhenElementRemoved() {
        var format = LogFormat.default
        format.mainLine.removeAll { $0 == .parameters }
        let formatter = CompactFormatter(profile: .mvvm, format: format)
        let event = makeEvent()
        let output = formatter.format(event: event, configuration: configuration)
        #expect(!output.contains("(id: 42)"))
        #expect(output.contains("fetchData"))
    }

    @Test func parameters_visibleByDefault() {
        let formatter = CompactFormatter(profile: .mvvm)
        let event = makeEvent()
        let output = formatter.format(event: event, configuration: configuration)
        #expect(output.contains("(id: 42)"))
    }

    @Test func traceEvent_parameters_suppressedWhenElementRemoved() {
        var format = LogFormat.default
        format.mainLine.removeAll { $0 == .parameters }
        let formatter = CompactFormatter(profile: .mvvm, format: format)
        let event = makeTraceEvent()
        let output = formatter.format(event: event, configuration: configuration)
        #expect(!output.contains("(id: 42)"))
        #expect(output.contains("fetchData"))
    }

    @Test func traceEvent_parameters_visibleByDefault() {
        let formatter = CompactFormatter(profile: .mvvm)
        let event = makeTraceEvent()
        let output = formatter.format(event: event, configuration: configuration)
        #expect(output.contains("(id: 42)"))
    }

    @Test func traceEvent_parameters_suppressedViaConfigurationLogFormat() {
        var format = LogFormat.default
        format.mainLine.removeAll { $0 == .parameters }
        let configWithoutParams = AutoLogConfiguration(logFormat: format)
        let formatter = CompactFormatter(profile: .mvvm)
        let event = makeTraceEvent()
        let output = formatter.format(event: event, configuration: configWithoutParams)
        #expect(!output.contains("(id: 42)"))
    }

    @Test func timing_usesNanosecondsBelowOneMicrosecond() {
        let formatter = CompactFormatter(profile: .mvvm)
        var event = makeEvent()
        event.duration = .nanoseconds(500)
        let output = formatter.format(event: event, configuration: configuration)
        #expect(output.contains("500ns"))
        #expect(!output.contains("⏱"))
    }

    @Test func timing_usesMicrosecondsBelowOneMillisecond() {
        let formatter = CompactFormatter(profile: .mvvm)
        var event = makeEvent()
        event.duration = .microseconds(250)
        let output = formatter.format(event: event, configuration: configuration)
        #expect(output.contains("250µs"))
        #expect(!output.contains("⏱"))
    }

    @Test func timing_usesMillisecondsBelowOneSecond() {
        let formatter = CompactFormatter(profile: .mvvm)
        var event = makeEvent()
        event.duration = .milliseconds(12)
        let output = formatter.format(event: event, configuration: configuration)
        #expect(output.contains("12ms"))
        #expect(!output.contains("⏱"))
    }

    @Test func timing_rendersOnlyOnceWhenTimingElementIsPresent() {
        let formatter = CompactFormatter(profile: .mvvm)
        var event = makeEvent()
        event.duration = .milliseconds(12)
        let output = formatter.format(event: event, configuration: configuration)
        #expect(output.components(separatedBy: "12ms").count == 2)
        #expect(output.components(separatedBy: "⏱").count == 1)
    }

    @Test func timing_isSuppressedWhenElementRemovedFromConfigurationLogFormat() {
        var format = LogFormat.default
        format.mainLine.removeAll { $0 == .timing }
        let configWithoutTiming = AutoLogConfiguration(logFormat: format)
        let formatter = CompactFormatter(profile: .mvvm)
        var event = makeEvent()
        event.duration = .milliseconds(12)
        let output = formatter.format(event: event, configuration: configWithoutTiming)
        #expect(!output.contains("⏱"))
    }

    @Test func timing_usesSecondsAtOneSecondOrMore() {
        let formatter = CompactFormatter(profile: .mvvm)
        var event = makeEvent()
        event.duration = .seconds(2)
        let output = formatter.format(event: event, configuration: configuration)
        #expect(output.contains("2s"))
        #expect(!output.contains("⏱"))
    }

    @Test func defaultFormat_roundTripsViaConfiguration() throws {
        let config = AutoLogConfiguration(logFormat: .default)
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(AutoLogConfiguration.self, from: data)
        #expect(decoded.logFormat == .default)
    }

    @Test func customFormat_persistsThroughConfiguration() throws {
        var format = LogFormat.default
        format.mainLine.removeAll { $0 == .returnValue }
        let config = AutoLogConfiguration(logFormat: format)
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(AutoLogConfiguration.self, from: data)
        #expect(!decoded.logFormat.mainLine.contains(.returnValue))
    }
}

// MARK: - Integration

@Suite(.serialized)
struct CompactFormatterIntegrationTests {
    let configuration = AutoLogConfiguration.default

    @Test func loggedMacro_emitsCompactFormat() {
        // Use a class box to capture the last formatted output in a @Sendable closure.
        // Workaround: @AutoLog(using: AutoLogLogger(formatter:)) inside a function body
        // triggers a Swift compiler ICE (ExpandBodyMacroRequest crash). Instead we override
        // Install a scoped runtime override and use @Log (no-arg) on the inner struct.
        final class Box: @unchecked Sendable { var value = "" }
        let box = Box()

        struct CapturingFormatter: AutoLogFormatter {
            let box: Box
            func format(event: AutoLogEvent, configuration: AutoLogConfiguration) -> String {
                let output = CompactFormatter().format(event: event, configuration: configuration)
                box.value = output
                return output
            }
        }
        let runtime = AutoLogRuntime(
            logger: AutoLogLogger(formatter: CapturingFormatter(box: box)),
            configuration: AutoLogConfiguration(emitStartEvents: false)
        )

        struct Subject {
            @Log
            func greet(name: String) -> String { "Hello, \(name)" }
        }

        AutoLog.withRuntime(runtime) {
            _ = Subject().greet(name: "World")
        }

        #expect(box.value.contains("🟢"))
        #expect(box.value.contains("greet(name: World)"))
        #expect(box.value.contains("→ Hello, World"))
    }
}

// MARK: - ArrowStyleTests

@Suite
struct ArrowStyleTests {
  let configuration = AutoLogConfiguration.default

  @Test func default_producesStandardArrows() {
    let style = LogFormat.ArrowStyle.default
    #expect(style.arrow(for: 1) == "->")
    #expect(style.arrow(for: 2) == "-->")
    #expect(style.arrow(for: 3) == "--->")
  }

  @Test func customStyle_producesExpectedArrows() {
    let style = LogFormat.ArrowStyle(start: "a", repeater: "b", end: ">")
    #expect(style.arrow(for: 1) == "a>")
    #expect(style.arrow(for: 2) == "ab>")
    #expect(style.arrow(for: 4) == "abbb>")
  }

  @Test func emptyRepeater_sameArrowAtAllDepths() {
    let style = LogFormat.ArrowStyle(start: "~", repeater: "", end: ">")
    #expect(style.arrow(for: 1) == "~>")
    #expect(style.arrow(for: 5) == "~>")
  }

  @Test func logFormat_decodesLegacyJsonWithoutArrowStyle() throws {
    // Simulate JSON written by an older version that has no arrowStyle key.
    let json = #"{"mainLine":["depthArrow","statusEmoji"]}"#
    let format = try JSONDecoder().decode(LogFormat.self, from: Data(json.utf8))
    #expect(format.arrowStyle == .default)
  }

  @Test func logFormat_roundTripsArrowStyle() throws {
    let original = LogFormat(
      mainLine: [.depthArrow, .functionName],
      arrowStyle: LogFormat.ArrowStyle(start: "a", repeater: "b", end: ">")
    )
    let data    = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(LogFormat.self, from: data)
    #expect(decoded.arrowStyle == original.arrowStyle)
  }

  @Test func compactFormatter_usesCustomArrow() {
    let format = LogFormat(
      mainLine: [.depthArrow, .statusEmoji, .functionName],
      arrowStyle: LogFormat.ArrowStyle(start: "~", repeater: "~", end: ">")
    )
    let formatter = CompactFormatter(profile: .mvvm, format: format)
    var event = AutoLogEvent(
      location: "App/MyViewModel.swift:1:1",
      declaration: "func doWork()"
    )
    event.duration = .milliseconds(0)
    let output = formatter.format(event: event, configuration: configuration)
    // ViewModel = depth 2 → "~~>"
    #expect(output.hasPrefix("~~>"))
  }
}

// MARK: - StatusStyleTests

@Suite
struct StatusStyleTests {
  let configuration = AutoLogConfiguration.default

  @Test func defaultStyle_matchesOriginalEmojis() {
    let s = LogFormat.StatusStyle.default
    #expect(s.start   == "🔵")
    #expect(s.success == "🟢")
    #expect(s.failure == "🔴")
    #expect(s.warning == "🟡")
    #expect(s.update  == "🟣")
  }

  @Test func logFormat_decodesLegacyJsonWithoutStatusStyle() throws {
    // Simulate JSON written by an older version that has no statusStyle key.
    let json = #"{"mainLine":["statusEmoji"],"arrowStyle":{"start":"-","repeater":"-","end":">"}}"#
    let format = try JSONDecoder().decode(LogFormat.self, from: Data(json.utf8))
    #expect(format.statusStyle == .default)
  }

  @Test func logFormat_roundTripsStatusStyle() throws {
    let original = LogFormat(
      mainLine: [.statusEmoji],
      statusStyle: LogFormat.StatusStyle(start: "▶", success: "✓", failure: "✗", warning: "!", update: "•")
    )
    let data    = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(LogFormat.self, from: data)
    #expect(decoded.statusStyle == original.statusStyle)
  }

  @Test func compactFormatter_usesCustomSuccessChar() {
    let format = LogFormat(
      mainLine: [.statusEmoji, .functionName],
      statusStyle: LogFormat.StatusStyle(success: "✓")
    )
    let formatter = CompactFormatter(profile: .mvvm, format: format)
    var event = AutoLogEvent(
      location: "App/MyViewModel.swift:1:1",
      declaration: "func doWork()"
    )
    event.result   = .success(())
    event.duration = .milliseconds(0)
    let output = formatter.format(event: event, configuration: configuration)
    #expect(output.contains("✓"))
    #expect(!output.contains("🟢"))
  }

  @Test func compactFormatter_usesCustomFailureChar() {
    let format = LogFormat(
      mainLine: [.statusEmoji, .functionName],
      statusStyle: LogFormat.StatusStyle(failure: "✗")
    )
    let formatter = CompactFormatter(profile: .mvvm, format: format)
    var event = AutoLogEvent(
      location: "App/MyViewModel.swift:1:1",
      declaration: "func doWork()"
    )
    event.result   = .failure(NSError(domain: "test", code: 0))
    event.duration = .milliseconds(0)
    let output = formatter.format(event: event, configuration: configuration)
    #expect(output.contains("✗"))
    #expect(!output.contains("🔴"))
  }
}
