import SwiftUI
import AppKit

/// A text field that selects all its content the moment it becomes focused.
///
/// On macOS, clicking a `TextField` places the cursor at the click position
/// rather than selecting all content. For short style fields (emoji, arrow
/// characters) the cursor almost always lands at position 0, so pressing
/// Backspace has nothing to delete and triggers a system beep.
///
/// This view fixes that by sending the standard "select all" Responder Chain
/// action one run-loop after focus is acquired — by which point the underlying
/// `NSTextField` editor is definitely first responder.
struct StyleTextField: View {
  @Binding var text: String
  var width: CGFloat = 52

  @FocusState private var isFocused: Bool

  var body: some View {
    TextField("", text: $text)
      .textFieldStyle(.roundedBorder)
      .font(.system(.body, design: .monospaced))
      .frame(width: width)
      .focused($isFocused)
      .onChange(of: isFocused) { _, focused in
        guard focused else { return }
        // Defer one run-loop so the NSTextField editor is first-responder
        // before the select-all action reaches it.
        DispatchQueue.main.async {
          NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
        }
      }
  }
}
