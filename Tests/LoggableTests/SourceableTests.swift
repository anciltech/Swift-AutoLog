import Loggable
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

    // MARK: - LoggableEvent source field

    @Test func event_withSource_carriesSource() {
        let event = LoggableEvent(
            source: InteractionSource.button("Deposit"),
            location: "App/ContentView.swift:30:5",
            declaration: "func deposit(_ amount: Decimal)"
        )
        #expect(event.source?.emoji == "👆🏼")
        #expect(event.source?.label == "Deposit")
    }

    @Test func event_withoutSource_hasNilSource() {
        let event = LoggableEvent(
            location: "App/MyView.swift:10:5",
            declaration: "func doSomething()"
        )
        #expect(event.source == nil)
    }
}

// MARK: - LoggableSource Tests

@Suite(.serialized)
struct LoggableSourceTests {

    @Test func current_isNilByDefault() {
        #expect(LoggableSource.current == nil)
    }

    @Test func run_setsCurrentDuringExecution() {
        var capturedEmoji: String?
        LoggableSource.run(InteractionSource.button("Test")) {
            capturedEmoji = LoggableSource.current?.emoji
        }
        #expect(capturedEmoji == "👆🏼")
    }

    @Test func run_restoresNilAfterExecution() {
        LoggableSource.run(InteractionSource.button("Test")) { }
        #expect(LoggableSource.current == nil)
    }

    @Test func run_async_setsCurrentDuringExecution() async {
        var capturedEmoji: String?
        await LoggableSource.run(InteractionSource.api("GET /users")) {
            capturedEmoji = LoggableSource.current?.emoji
        }
        #expect(capturedEmoji == "🌐")
    }

    @Test func run_emitsInteractionEvent() {
        let originalLogger = LoggableSource.logger
        defer { LoggableSource.logger = originalLogger }

        let mock = MockLogger()
        LoggableSource.logger = mock

        LoggableSource.run(InteractionSource.button("Deposit")) { }

        #expect(mock.events.count == 1)
        #expect(mock.events.first?.source?.emoji == "👆🏼")
        #expect(mock.events.first?.declaration == "button(\"Deposit\")")
    }

    @Test func run_returnsOperationResult() {
        let result = LoggableSource.run(InteractionSource.button("Calc")) { 42 }
        #expect(result == 42)
    }

    @Test func run_async_returnsOperationResult() async {
        let result = await LoggableSource.run(InteractionSource.api("Fetch")) { "data" }
        #expect(result == "data")
    }
}

// MARK: - CompactFormatter Source Tests

@Suite
struct CompactFormatterSourceTests {

    func makeEvent(
        level: (any Levelable)? = nil,
        source: (any Sourceable)? = nil,
        location: String = "App/MyViewModel.swift:10:5",
        declaration: String = "func doSomething()",
        parameters: [String: Any] = [:],
        result: Result<Any, any Error> = .success(()),
        tags: [any Taggable] = []
    ) -> LoggableEvent {
        LoggableEvent(
            level: level,
            source: source,
            location: location,
            declaration: declaration,
            parameters: parameters,
            result: result,
            tags: tags
        )
    }

    // In the new formatter, source emoji no longer replaces the status emoji on function events.
    // Status emoji (🟢/🔴/🔵) is always used; source attribution appears on a second ↖ line
    // only when the source is a SourceContext (set by LoggableSource.run via @TaskLocal).

    @Test func functionEvent_withSource_showsStatusEmoji_notSourceEmoji() {
        // Non-SourceContext sources don't produce an attribution line.
        let event = makeEvent(
            source: InteractionSource.button("Deposit"),
            result: .success(())
        )
        let output = CompactFormatter().format(event: event)
        #expect(!output.contains("👆🏼"))  // Source emoji NOT on function line
        #expect(output.contains("🟢"))     // Status emoji IS shown
    }

    @Test func functionEvent_failure_showsRedEmoji_notSourceEmoji() {
        struct E: Error {}
        let event = makeEvent(
            source: InteractionSource.api("GET /users"),
            result: .failure(E())
        )
        let output = CompactFormatter().format(event: event)
        #expect(!output.contains("🌐"))   // Source emoji NOT on function line
        #expect(output.contains("🔴"))    // Failure emoji IS shown
    }

    @Test func noSource_fallsBackToStatusEmoji() {
        let event = makeEvent(result: .success(()))
        let output = CompactFormatter().format(event: event)
        #expect(output.contains("🟢"))
    }

    @Test func interactionEvent_usesLabelAndLocation() {
        // Interaction events (declaration == source.description) are formatted as:
        // "-> 👆🏼 <label> [<TypeName>:<line>]"
        let event = makeEvent(
            source: InteractionSource.button("Deposit"),
            location: "App/ContentView.swift:30:5",
            declaration: "button(\"Deposit\")"
        )
        let output = CompactFormatter().format(event: event)
        #expect(output.contains("👆🏼"))
        #expect(output.contains("Deposit"))
        #expect(output.contains("[ContentView:30]"))
        #expect(!output.contains("→"))
    }

    @Test func interactionEvent_usesDepthArrow() {
        // Depth arrow length is derived from the type name suffix via DepthProfile.
        let event = makeEvent(
            source: InteractionSource.toggle("Dark Mode"),
            location: "App/MyViewModel.swift:15:5",
            declaration: "toggle(\"Dark Mode\")"
        )
        let output = CompactFormatter(profile: .mvvm).format(event: event)
        #expect(output.hasPrefix("--> 🔀 Dark Mode [MyViewModel:15]"))
    }

    @Test func downstreamFunction_showsStatusEmoji_noSourceEmoji() {
        // When source is set but declaration doesn't match source.description,
        // it's a downstream @Logged function. Status emoji is used; source emoji
        // only appears in the ↖ attribution line (for SourceContext sources only).
        let event = makeEvent(
            source: InteractionSource.button("Deposit"),
            location: "App/Account.swift:20:5",
            declaration: "func deposit(_ amount: Decimal)",
            parameters: ["amount": 50],
            result: .success(())
        )
        let output = CompactFormatter().format(event: event)
        #expect(!output.contains("👆🏼"))  // Source emoji NOT on function line
        #expect(output.contains("🟢"))     // Status emoji shown
        #expect(output.contains("Account.deposit(amount: 50)"))
    }

    @Test func functionEvent_withSourceContext_showsAttributionLine() {
        // When source is a SourceContext (from LoggableSource.run), a second ↖ line
        // is appended showing the interaction source emoji, label, and call-site location.
        let ctx = SourceContext(
            source: InteractionSource.button("Deposit"),
            location: "App/ContentView.swift:30:5"
        )
        let event = makeEvent(
            source: ctx,
            declaration: "func deposit(_ amount: Decimal)",
            result: .success(())
        )
        let output = CompactFormatter().format(event: event)
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 2)
        #expect(lines[0].contains("🟢"))
        #expect(lines[1].contains("↖"))
        #expect(lines[1].contains("👆🏼"))
        #expect(lines[1].contains("Deposit"))
        #expect(lines[1].contains("[ContentView:30]"))
    }
}
