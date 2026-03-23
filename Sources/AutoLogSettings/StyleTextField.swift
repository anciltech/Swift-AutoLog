import SwiftUI
import AppKit

/// A text field that:
/// 1. Selects all its content when it becomes first responder, so the user
///    can immediately type a replacement value.
/// 2. Blocks external @Observable re-renders from resetting the displayed
///    text while the user is actively editing.
///
/// The SwiftUI TextField approach fails for (2): when the binding setter
/// mutates an @Observable ViewModel, SwiftUI re-renders the view immediately,
/// which can reset the field's content before the deletion completes.
/// NSViewRepresentable gives us direct access to the NSTextField delegate so
/// we can guard updateNSView with an `isEditing` flag.
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
    // While the user is editing, never override what they've typed —
    // the binding's setter already stored the value; we just don't want
    // @Observable-triggered re-renders to snap the displayed text back.
    guard !context.coordinator.isEditing else { return }
    if nsView.stringValue != text {
      nsView.stringValue = text
    }
  }

  func makeCoordinator() -> Coordinator { Coordinator(text: $text) }
}

// MARK: - Coordinator

extension StyleTextField {

  final class Coordinator: NSObject, NSTextFieldDelegate {
    @Binding var text: String
    var isEditing = false

    init(text: Binding<String>) { _text = text }

    /// Called the moment the field editor activates — guaranteed timing for selectAll.
    func controlTextDidBeginEditing(_ obj: Notification) {
      isEditing = true
      guard let field  = obj.object as? NSTextField,
            let editor = field.currentEditor() else { return }
      editor.selectAll(nil)
    }

    func controlTextDidChange(_ obj: Notification) {
      guard let field = obj.object as? NSTextField else { return }
      text = field.stringValue
    }

    func controlTextDidEndEditing(_ obj: Notification) {
      isEditing = false
    }
  }
}
