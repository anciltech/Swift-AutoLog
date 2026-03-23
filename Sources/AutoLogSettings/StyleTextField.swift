import SwiftUI
import AppKit

/// A text field for short style values (arrow characters, status emoji) that:
///
/// 1. **Selects all content on focus** — clicking anywhere in the field
///    immediately selects the current value so the user can replace it by
///    typing, without needing to manually select first.
///
/// 2. **Never re-renders during editing** — changes are buffered locally and
///    only written to the binding when the field loses focus.  Committing mid-
///    edit would mutate the @Observable ViewModel, trigger a SwiftUI re-render,
///    and call updateNSView before the deletion animation finished — snapping
///    the displayed text back to the old value even though deletion succeeded.
struct StyleTextField: NSViewRepresentable {
  @Binding var text: String

  func makeNSView(context: Context) -> AutoSelectTextField {
    let field = AutoSelectTextField()
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

  func updateNSView(_ nsView: AutoSelectTextField, context: Context) {
    // Only accept external updates when the field is not being edited.
    // Skipping during editing prevents @Observable re-renders from resetting
    // the displayed text while the user is still interacting with the field.
    guard !context.coordinator.isEditing else { return }
    if nsView.stringValue != text {
      nsView.stringValue = text
    }
  }

  func makeCoordinator() -> Coordinator { Coordinator(text: $text) }
}

// MARK: - AutoSelectTextField

/// NSTextField subclass that selects all text on mouse-click, so the user
/// immediately sees their current value highlighted and ready to replace.
final class AutoSelectTextField: NSTextField {
  override func mouseDown(with event: NSEvent) {
    super.mouseDown(with: event)
    selectText(nil)
  }
}

// MARK: - Coordinator

extension StyleTextField {

  final class Coordinator: NSObject, NSTextFieldDelegate {
    @Binding var text: String
    var isEditing = false
    /// Local buffer — changes stay here until focus leaves the field.
    private var pendingText: String = ""

    init(text: Binding<String>) { _text = text }

    func controlTextDidBeginEditing(_ obj: Notification) {
      isEditing = true
      pendingText = text
    }

    /// Buffer changes locally — do NOT write to the binding here.
    /// Writing mid-edit triggers an @Observable re-render which calls
    /// updateNSView and resets the field's displayed text.
    func controlTextDidChange(_ obj: Notification) {
      guard let field = obj.object as? NSTextField else { return }
      pendingText = field.stringValue
    }

    /// Only commit to the binding once editing ends (focus lost / Tab / Return).
    /// At this point there are no active re-renders to interfere.
    func controlTextDidEndEditing(_ obj: Notification) {
      text = pendingText
      isEditing = false
    }
  }
}
