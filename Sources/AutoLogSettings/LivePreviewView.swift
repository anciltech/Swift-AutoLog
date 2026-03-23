import SwiftUI
import AutoLog

/// Right-hand panel: live formatted output preview.
struct LivePreviewView: View {
  let format: LogFormat

  // A fixed DepthProfile for preview purposes (ViewModel → depth 2 → "-->")
  private let profile = DepthProfile.mvvm

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // ── Header ──────────────────────────────────────────────────────────────
      VStack(alignment: .leading, spacing: 2) {
        Text("Live Preview")
          .font(.headline)
        Text("Example output with your current format")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .padding([.horizontal, .top], 16)
      .padding(.bottom, 10)

      Divider()

      // ── Preview content ──────────────────────────────────────────────────────
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          previewGroup(
            title: "Success",
            lines: successLines()
          )

          previewGroup(
            title: "Failure",
            lines: failureLines()
          )

          previewGroup(
            title: "Tagged",
            lines: taggedLines()
          )

          previewGroup(
            title: "Interaction (always fixed)",
            lines: interactionLines()
          )
        }
        .padding(16)
      }

      Divider()

      // ── Format code snippet ──────────────────────────────────────────────────
      VStack(alignment: .leading, spacing: 4) {
        Text("Active elements:")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(elementSummary)
          .font(.system(.caption, design: .monospaced))
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
      .padding(12)
    }
    .frame(minWidth: 360)
  }

  // MARK: - Helpers

  @ViewBuilder
  private func previewGroup(title: String, lines: [String]) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)
        .textCase(.uppercase)

      VStack(alignment: .leading, spacing: 4) {
        ForEach(lines, id: \.self) { line in
          Text(line)
            .font(.system(.body, design: .monospaced))
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .padding(10)
      .background(.background.secondary)
      .clipShape(RoundedRectangle(cornerRadius: 6))
    }
  }

  // MARK: - Example events

  private var formatter: CompactFormatter {
    CompactFormatter(profile: profile, format: format)
  }

  private func successLines() -> [String] {
    [
      formatter.format(event: makeEvent(
        location: "App/MyViewModel.swift:42:5",
        declaration: "func fetchData(userId: Int) async",
        parameters: ["userId": 42],
        result: .success("User(id: 1)")
      ))
    ]
  }

  private func failureLines() -> [String] {
    struct NetworkError: Error, CustomStringConvertible {
      var description: String { "notFound" }
    }
    return [
      formatter.format(event: makeEvent(
        location: "App/MyViewModel.swift:42:5",
        declaration: "func fetchData(userId: Int) async",
        parameters: ["userId": 99],
        result: .failure(NetworkError())
      ))
    ]
  }

  private func taggedLines() -> [String] {
    [
      formatter.format(event: makeEvent(
        location: "App/AccountService.swift:18:5",
        declaration: "func processPayment(amount: Decimal)",
        parameters: ["amount": "49.99"],
        result: .success(()),
        tags: ["payments", "critical"]
      ))
    ]
  }

  private func interactionLines() -> [String] {
    [
      formatter.format(event: makeEvent(
        location: "App/ContentView.swift:30:5",
        declaration: "button(\"Deposit\")",
        source: InteractionSource.button("Deposit"),
        result: .success(())
      ))
    ]
  }

  private func makeEvent(
    location: String,
    declaration: String,
    source: (any Sourceable)? = nil,
    parameters: [String: Any] = [:],
    result: Result<Any, any Error> = .success(()),
    tags: [any Taggable] = []
  ) -> AutoLogEvent {
    var event = AutoLogEvent(
      source: source,
      location: location,
      declaration: declaration,
      parameters: parameters,
      result: result,
      tags: tags
    )
    event.duration = .milliseconds(12)
    return event
  }

  private var elementSummary: String {
    format.mainLine.map { ".\($0.rawValue)" }.joined(separator: " · ")
  }
}
