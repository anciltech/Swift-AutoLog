import AutoLog
import Testing

@Suite
struct SourceableTests {

    // MARK: - Emoji mapping

    @Test func button_hasCorrectEmoji() {
        #expect(InteractionSource.button("Deposit").emoji == "👆🏼")
    }

    @Test func textField_hasCorrectEmoji() {
        #expect(InteractionSource.textField("Search").emoji == "💬")
    }

    @Test func keyboard_hasCorrectEmoji() {
        #expect(InteractionSource.keyboard("Return").emoji == "⌨️")
    }

    @Test func toggle_hasCorrectEmoji() {
        #expect(InteractionSource.toggle("Dark Mode").emoji == "🔀")
    }

    @Test func gesture_hasCorrectEmoji() {
        #expect(InteractionSource.gesture("Swipe").emoji == "🤌🏼")
    }

    @Test func api_hasCorrectEmoji() {
        #expect(InteractionSource.api("GET /users").emoji == "🌐")
    }

    @Test func system_hasCorrectEmoji() {
        #expect(InteractionSource.system("ScenePhase").emoji == "⚙️")
    }

    @Test func timer_hasCorrectEmoji() {
        #expect(InteractionSource.timer("Refresh").emoji == "⏱️")
    }

    @Test func unknown_hasCorrectEmoji() {
        #expect(InteractionSource.unknown.emoji == "❓")
    }

    // MARK: - Label

    @Test func button_hasLabel() {
        #expect(InteractionSource.button("Deposit").label == "Deposit")
    }

    @Test func nilLabel_returnsNil() {
        #expect(InteractionSource.button(nil).label == nil)
    }

    @Test func unknown_hasNilLabel() {
        #expect(InteractionSource.unknown.label == nil)
    }

    // MARK: - Description

    @Test func button_description_includesLabel() {
        #expect(InteractionSource.button("Deposit").description == "button(\"Deposit\")")
    }

    @Test func button_description_nilLabel() {
        #expect(InteractionSource.button(nil).description == "button")
    }

    @Test func unknown_description() {
        #expect(InteractionSource.unknown.description == "unknown")
    }

    // MARK: - AutoLogInteraction aliases

    @Test func interactionNamespace_buildsButtonSource() {
        let source = AutoLogInteraction.button("Deposit")
        #expect(source.emoji == "👆🏼")
        #expect(source.label == "Deposit")
        #expect(source.description == "button(\"Deposit\")")
    }

    @Test func interactionNamespace_unknownMatchesBuiltInUnknown() {
        #expect(AutoLogInteraction.unknown.description == InteractionSource.unknown.description)
    }

    // MARK: - Custom Sourceable conformance

    @Test func customSourceable_works() {
        enum MySource: Sourceable {
            case deepLink(URL)

            var emoji: String { "🔗" }
            var label: String? {
                switch self {
                case .deepLink(let url): url.absoluteString
                }
            }
            var description: String { "deepLink(\"\(label ?? "")\")" }
        }

        let source = MySource.deepLink(URL(string: "https://example.com")!)
        #expect(source.emoji == "🔗")
        #expect(source.label == "https://example.com")
    }

    // MARK: - AutoLogEvent source field

    @Test func event_withSource_carriesSource() {
        let event = AutoLogEvent(
            source: InteractionSource.button("Deposit"),
            location: "App/ContentView.swift:30:5",
            declaration: "func deposit(_ amount: Decimal)"
        )
        #expect(event.source?.emoji == "👆🏼")
        #expect(event.source?.label == "Deposit")
    }

    @Test func event_withoutSource_hasNilSource() {
        let event = AutoLogEvent(
            location: "App/MyView.swift:10:5",
            declaration: "func doSomething()"
        )
        #expect(event.source == nil)
    }
}

// MARK: - AutoLogSource Tests

@Suite(.serialized)
struct AutoLogSourceTests {
    private func withMockRuntime<T>(
        logger: MockLogger = MockLogger(),
        operation: () throws -> T
    ) rethrows -> T {
        try AutoLog.withRuntime(
            AutoLogRuntime(
                logger: logger,
                configuration: .default
            ),
            operation: operation
        )
    }

    private func withMockRuntime<T>(
        logger: MockLogger = MockLogger(),
        operation: () async throws -> T
    ) async rethrows -> T {
        try await AutoLog.withRuntime(
            AutoLogRuntime(
                logger: logger,
                configuration: .default
            ),
            operation: operation
        )
    }

    @Test func current_isNilByDefault() {
        #expect(AutoLogSource.current == nil)
    }

    @Test func run_setsCurrentDuringExecution() {
        withMockRuntime {
            var capturedEmoji: String?
            var capturedInteractionID: String?
            AutoLogSource.run(InteractionSource.button("Test")) {
                capturedEmoji = AutoLogSource.current?.emoji
                capturedInteractionID = AutoLogSource.current?.interactionID
            }
            #expect(capturedEmoji == "👆🏼")
            #expect(capturedInteractionID?.count == 6)
        }
    }

    @Test func run_restoresNilAfterExecution() {
        withMockRuntime {
            AutoLogSource.run(InteractionSource.button("Test")) { }
            #expect(AutoLogSource.current == nil)
        }
    }

    @Test func run_async_setsCurrentDuringExecution() async {
        await withMockRuntime {
            var capturedEmoji: String?
            await AutoLogSource.run(InteractionSource.api("GET /users")) {
                capturedEmoji = AutoLogSource.current?.emoji
            }
            #expect(capturedEmoji == "🌐")
        }
    }

    @Test func run_emitsInteractionEvent() {
        let mock = MockLogger()
        withMockRuntime(logger: mock) {
            AutoLogSource.run(InteractionSource.button("Deposit")) { }
            #expect(mock.events.count == 1)
            #expect(mock.events.first?.source?.emoji == "👆🏼")
            #expect(mock.events.first?.declaration == "button(\"Deposit\")")
            let context = mock.events.first?.source as? SourceContext
            #expect(context != nil)
            #expect(context?.interactionID.count == 6)
        }
    }

    @Test func run_returnsOperationResult() {
        withMockRuntime {
            let result = AutoLogSource.run(InteractionSource.button("Calc")) { 42 }
            #expect(result == 42)
        }
    }

    @Test func source_log_setsCurrentDuringExecution() {
        withMockRuntime {
            var capturedEmoji: String?
            InteractionSource.keyboard("Toggle").log {
                capturedEmoji = AutoLogSource.current?.emoji
            }
            #expect(capturedEmoji == "⌨️")
        }
    }

    @Test func source_log_emitsInteractionEvent() {
        let mock = MockLogger()
        withMockRuntime(logger: mock) {
            InteractionSource.keyboard("Toggle").log { }
            #expect(mock.events.count == 1)
            #expect(mock.events.first?.source?.emoji == "⌨️")
            #expect(mock.events.first?.declaration == "keyboard(\"Toggle\")")
        }
    }

    @Test func interactionNamespace_log_emitsInteractionEvent() {
        let mock = MockLogger()
        withMockRuntime(logger: mock) {
            AutoLogInteraction.button("Frame Button").log { }
            #expect(mock.events.count == 1)
            #expect(mock.events.first?.source?.emoji == "👆🏼")
            #expect(mock.events.first?.declaration == "button(\"Frame Button\")")
        }
    }

    @Test func run_async_returnsOperationResult() async {
        await withMockRuntime {
            let result = await AutoLogSource.run(InteractionSource.api("Fetch")) { "data" }
            #expect(result == "data")
        }
    }

    @Test func source_log_async_returnsOperationResult() async {
        await withMockRuntime {
            let result = await InteractionSource.api("Fetch").log { "data" }
            #expect(result == "data")
        }
    }
}

// MARK: - CompactFormatter Source Tests

@Suite
struct CompactFormatterSourceTests {
    private let configuration = AutoLogConfiguration.default

    func makeEvent(
        level: (any Levelable)? = nil,
        source: (any Sourceable)? = nil,
        location: String = "App/MyViewModel.swift:10:5",
        declaration: String = "func doSomething()",
        parameters: [String: Any] = [:],
        result: Result<Any, any Error> = .success(()),
        tags: [any Taggable] = []
    ) -> AutoLogEvent {
        AutoLogEvent(
            level: level,
            source: source,
            location: location,
            declaration: declaration,
            parameters: parameters,
            result: result,
            tags: tags
        )
    }

    // Source-propagated function events render as trace-tree branches.
    // Status emoji (🟢/🔴/🔵) stays on the branch tip while the interaction
    // itself is emitted as a standalone root line.

    @Test func functionEvent_withSource_showsStatusEmoji_notSourceEmoji() {
        // Non-SourceContext sources don't produce an attribution line.
        let event = makeEvent(
            source: InteractionSource.button("Deposit"),
            result: .success(())
        )
        let output = CompactFormatter().format(event: event, configuration: configuration)
        #expect(!output.contains("👆🏼"))  // Source emoji NOT on function line
        #expect(output.contains("🟢"))     // Status emoji IS shown
    }

    @Test func functionEvent_failure_showsRedEmoji_notSourceEmoji() {
        struct E: Error {}
        let event = makeEvent(
            source: InteractionSource.api("GET /users"),
            result: .failure(E())
        )
        let output = CompactFormatter().format(event: event, configuration: configuration)
        #expect(!output.contains("🌐"))   // Source emoji NOT on function line
        #expect(output.contains("🔴"))    // Failure emoji IS shown
    }

    @Test func noSource_fallsBackToStatusEmoji() {
        let event = makeEvent(result: .success(()))
        let output = CompactFormatter().format(event: event, configuration: configuration)
        #expect(output.contains("🟢"))
    }

    @Test func interactionEvent_usesLabelAndLocation() {
        let event = makeEvent(
            source: InteractionSource.button("Deposit"),
            location: "App/ContentView.swift:30:5",
            declaration: "button(\"Deposit\")"
        )
        let output = CompactFormatter().format(event: event, configuration: configuration)
        #expect(output == "👆🏼 Deposit")
    }

    @Test func interactionEvent_usesDepthArrow() {
        let event = makeEvent(
            source: InteractionSource.toggle("Dark Mode"),
            location: "App/MyViewModel.swift:15:5",
            declaration: "toggle(\"Dark Mode\")"
        )
        let output = CompactFormatter(profile: .mvvm).format(event: event, configuration: configuration)
        #expect(output == "🔀 Dark Mode")
    }

    @Test func downstreamFunction_showsStatusEmoji_noSourceEmoji() {
        let event = makeEvent(
            source: InteractionSource.button("Deposit"),
            location: "App/Account.swift:20:5",
            declaration: "func deposit(_ amount: Decimal)",
            parameters: ["amount": 50],
            result: .success(())
        )
        let output = CompactFormatter().format(event: event, configuration: configuration)
        #expect(!output.contains("👆🏼"))  // Source emoji NOT on function line
        #expect(output.contains("🟢"))     // Status emoji shown
        #expect(output.contains("Account.deposit(amount: 50)"))
    }

    @Test func functionEvent_withSourceContext_showsTraceBranch() {
        let ctx = SourceContext(
            source: InteractionSource.button("Deposit"),
            location: "App/ContentView.swift:30:5"
        )
        let event = makeEvent(
            source: ctx,
            declaration: "func deposit(_ amount: Decimal)",
            result: .success(())
        )
        let output = CompactFormatter().format(event: event, configuration: configuration)
        #expect(output.contains("└──🟢"))
        #expect(output.contains("MyViewModel.deposit()"))
        #expect(!output.contains("↖"))
    }

    @Test func interactionEvent_withSourceContext_showsTraceBadgeInline() {
        let ctx = SourceContext(
            source: InteractionSource.button("Deposit"),
            location: "App/ContentView.swift:30:5",
            interactionID: "A1B2C3",
            flowMarker: "🧵"
        )
        let event = makeEvent(
            source: ctx,
            location: "App/ContentView.swift:30:5",
            declaration: "button(\"Deposit\")"
        )
        let output = CompactFormatter().format(event: event, configuration: configuration)
        #expect(output.contains("👆🏼-🧵A1B2C3"))
        #expect(output.hasSuffix("👆🏼 Deposit"))
    }

    @Test func failureTrace_usesLongerBranchAndInlineError() {
        struct PaymentError: Error {}
        let ctx = SourceContext(
            source: InteractionSource.button("Save"),
            location: "App/ContentView.swift:30:5",
            interactionID: "A1B2C3",
            flowMarker: "🧵"
        )
        let event = makeEvent(
            source: ctx,
            location: "App/PaymentAPI.swift:30:5",
            declaration: "func submit() async throws",
            result: .failure(PaymentError())
        )

        let output = CompactFormatter(profile: .cleanArchitecture).format(event: event, configuration: configuration)
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines[0].contains("└─────🔴"))
        #expect(lines[0].contains("PaymentAPI.submit() async"))
        #expect(lines[0].contains("PaymentError"))
    }

    @Test func successTrace_usesTerminalBranchPrefix() {
        let ctx = SourceContext(
            source: InteractionSource.button("Save"),
            location: "App/ContentView.swift:30:5",
            interactionID: "A1B2C3",
            flowMarker: "🧵"
        )
        let event = makeEvent(
            source: ctx,
            location: "App/PaymentService.swift:30:5",
            declaration: "func validate() async -> Bool",
            result: .success(true)
        )

        let output = CompactFormatter(profile: .cleanArchitecture).format(event: event, configuration: configuration)
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines[0].contains("└──🟢"))
        #expect(lines[0].contains("PaymentService.validate() async → true"))
    }

    @Test func traceEvent_earlyExit_showsOnSecondLine() {
        let ctx = SourceContext(
            source: InteractionSource.button("Load"),
            location: "App/ContentView.swift:10:5"
        )
        var event = makeEvent(
            source: ctx,
            location: "App/MyViewModel.swift:20:5",
            declaration: "func loadProfile(id:)",
            result: .success(())
        )
        event.setEarlyExit(kind: .if, intent: .optimize, condition: "isCached", message: "cache hit")

        let output = CompactFormatter().format(event: event, configuration: configuration)
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 2)
        #expect(lines[1].contains("↘️"))
        #expect(lines[1].contains("isCached"))
        #expect(lines[1].contains("optimize"))
        #expect(lines[1].contains("cache hit"))
    }

    @Test func traceEvent_branchDecision_showsOnSecondLine() {
        let ctx = SourceContext(
            source: InteractionSource.toggle("Dark Mode"),
            location: "App/ContentView.swift:10:5"
        )
        var event = makeEvent(
            source: ctx,
            location: "App/MyViewModel.swift:20:5",
            declaration: "func toggleDarkMode(isOn:)",
            result: .success(())
        )
        event.recordBranchDecision(kind: .if, condition: "isOn")

        let output = CompactFormatter().format(event: event, configuration: configuration)
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 2)
        #expect(lines[1].contains("branch path"))
        #expect(lines[1].contains("if branch condition=isOn"))
    }
}
