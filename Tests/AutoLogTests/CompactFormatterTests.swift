import AutoLog
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
        let prevEmitStart = AutoLogSettingsStorage.emitStartEvents
        LoggableSource.logger = LoggableLogger(formatter: CapturingFormatter(box: box))
        AutoLogSettingsStorage.emitStartEvents = false
        defer {
            LoggableSource.logger = prevLogger
            AutoLogSettingsStorage.emitStartEvents = prevEmitStart
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

// MARK: - ArrowStyleTests

@Suite
struct ArrowStyleTests {

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
    var event = LoggableEvent(
      location: "App/MyViewModel.swift:1:1",
      declaration: "func doWork()"
    )
    event.duration = .milliseconds(0)
    let output = formatter.format(event: event)
    // ViewModel = depth 2 → "~~>"
    #expect(output.hasPrefix("~~>"))
  }
}

// MARK: - StatusStyleTests

@Suite
struct StatusStyleTests {

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
    var event = LoggableEvent(
      location: "App/MyViewModel.swift:1:1",
      declaration: "func doWork()"
    )
    event.result   = .success(())
    event.duration = .milliseconds(0)
    let output = formatter.format(event: event)
    #expect(output.contains("✓"))
    #expect(!output.contains("🟢"))
  }

  @Test func compactFormatter_usesCustomFailureChar() {
    let format = LogFormat(
      mainLine: [.statusEmoji, .functionName],
      statusStyle: LogFormat.StatusStyle(failure: "✗")
    )
    let formatter = CompactFormatter(profile: .mvvm, format: format)
    var event = LoggableEvent(
      location: "App/MyViewModel.swift:1:1",
      declaration: "func doWork()"
    )
    event.result   = .failure(NSError(domain: "test", code: 0))
    event.duration = .milliseconds(0)
    let output = formatter.format(event: event)
    #expect(output.contains("✗"))
    #expect(!output.contains("🔴"))
  }
}
