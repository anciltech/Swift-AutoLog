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
}
