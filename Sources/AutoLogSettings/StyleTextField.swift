import SwiftUI
import AppKit

/// A text field for short style values (arrow characters, status emoji).
///
/// Two problems solved here that plain SwiftUI TextField cannot handle:
///
/// **1. Select-all on focus**
/// `controlTextDidBeginEditing` calls `editor.selectAll(nil)` the moment
/// the AppKit field editor activates.  This is the only reliable hook —
/// calling `selectText(nil)` from `mouseDown` triggers `makeFirstResponder`
/// externally, which SwiftUI's focus engine intercepts and re-assigns before
/// key events arrive, leaving the field visually selected but deaf to typing.
///
/// **2. No re-render during editing**
/// `controlTextDidChange` buffers changes in `pendingText` without touching
/// the `@Binding`.  Only `controlTextDidEndEditing` (Tab / Return / click-
/// away) writes to the binding and triggers an `@Observable` re-render.
/// Writing mid-edit causes SwiftUI to call `updateNSView` and snap the
/// displayed text back to the pre-edit value before the operation finishes.
struct StyleTextField: NSViewRepresentable {
  @Binding var text: String

  func makeNSView(context: Context) -> NSTextField {
    let field = NSTextField()
    field.stringValue = text
    field.placeholderString = ""
    field.delegate = context.coordinator
    field.bezelStyle = .roundedBezel
    field.isBezeled = true
    field.focusRingType = .default
    field.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
    field.cell?.wraps = false
    field.cell?.isScrollable = true
    return field
  }

  func updateNSView(_ nsView: NSTextField, context: Context) {
    guard !context.coordinator.isEditing else { return }
    if nsView.stringValue != text {
      nsView.stringValue = text
    }
  }

  func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

  // MARK: - Coordinator

  final class Coordinator: NSObject, NSTextFieldDelegate {
    @Binding var text: String
    var isEditing = false
    private var pendingText: String = ""

    init(text: Binding<String>) { _text = text }

    func controlTextDidBeginEditing(_ obj: Notification) {
      isEditing = true
      pendingText = text
      // selectAll via the live field editor — guaranteed to be first responder
      // at this point, so typing immediately replaces the selected value.
      guard let field  = obj.object as? NSTextField,
            let editor = field.currentEditor() else { return }
      editor.selectAll(nil)
    }

    /// Buffer locally — no binding write, no @Observable re-render while editing.
    func controlTextDidChange(_ obj: Notification) {
      guard let field = obj.object as? NSTextField else { return }
      pendingText = field.stringValue
    }

    /// Commit once focus leaves; re-render is safe at this point.
    func controlTextDidEndEditing(_ obj: Notification) {
      text = pendingText
      isEditing = false
    }
  }
}
