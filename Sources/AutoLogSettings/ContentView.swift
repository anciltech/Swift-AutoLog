import SwiftUI
import AutoLog

/// Root view: two-panel layout with the format editor on the left
/// and the live preview on the right.
struct ContentView: View {
  @State private var viewModel = SettingsViewModel()
  @State private var showCopiedBanner = false

  var body: some View {
    HStack(spacing: 0) {
      // ── Left: Format editor ────────────────────────────────────────────────
      FormatEditorView(viewModel: viewModel)

      Divider()

      // ── Right: Live preview ────────────────────────────────────────────────
      LivePreviewView(format: viewModel.currentFormat)
    }
    .frame(minHeight: 480)
    .overlay(alignment: .top) {
      if showCopiedBanner {
        copiedBanner
          .transition(.move(edge: .top).combined(with: .opacity))
      }
    }
    .animation(.easeInOut(duration: 0.25), value: showCopiedBanner)
    .toolbar {
      ToolbarItem(placement: .automatic) {
        Button {
          copyCodeAndShowBanner()
        } label: {
          Label("Copy Code Snippet", systemImage: "doc.on.doc")
        }
        .help("Copy a Swift snippet to paste into your app's startup code")
      }
    }
  }

  // MARK: - Copied banner

  @ViewBuilder
  private var copiedBanner: some View {
    HStack(spacing: 6) {
      Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(.green)
      Text("Snippet copied to clipboard")
        .font(.callout)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
    .background(.regularMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .shadow(radius: 4)
    .padding(.top, 12)
  }

  private func copyCodeAndShowBanner() {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(viewModel.codeSnippet, forType: .string)
    showCopiedBanner = true
    Task {
      try? await Task.sleep(for: .seconds(2))
      showCopiedBanner = false
    }
  }
}
