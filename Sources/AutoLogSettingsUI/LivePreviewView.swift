import SwiftUI
import AutoLog

/// Right-hand panel: live formatted output preview for the selected output profile.
struct LivePreviewView: View {
  let output: AutoLogOutput

  private let profile = DepthProfile.mvvm

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 2) {
        Text("Live Preview")
          .font(.headline)
        Text("Shows only the sample events that pass the selected output's shared runtime filters")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .padding([.horizontal, .top], 16)
      .padding(.bottom, 10)

      Divider()

      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          previewGroup(title: "Interaction", event: interactionEvent)
          previewGroup(title: "Start", event: startEvent)
          previewGroup(title: "Success", event: successEvent)
          previewGroup(title: "Failure", event: failureEvent)
          previewGroup(title: "Firebase VM Result", event: firebaseViewModelEvent)
        }
        .padding(16)
      }

      Divider()

      VStack(alignment: .leading, spacing: 4) {
        Text("Output summary:")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(summaryText)
          .font(.system(.caption, design: .monospaced))
          .foregroundStyle(.secondary)
      }
      .padding(12)
    }
    .frame(minWidth: 360)
  }

  @ViewBuilder
  private func previewGroup(title: String, event: AutoLogEvent) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)
        .textCase(.uppercase)

      VStack(alignment: .leading, spacing: 4) {
        if matches(event) {
          Text(formatter.format(event: eventWithContext(event), configuration: configuration))
            .font(.system(.body, design: .monospaced))
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
        } else {
          Text("Filtered out by this output profile")
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(.tertiary)
        }
      }
      .padding(10)
      .background(.background.secondary)
      .clipShape(RoundedRectangle(cornerRadius: 6))
    }
  }

  private var formatter: CompactFormatter {
    CompactFormatter(profile: profile, format: output.logFormat)
  }

  private var configuration: AutoLogConfiguration {
    AutoLogConfiguration(
      measureTimingDefault: output.measureTiming,
      measureTimingDepths: output.timingDepths,
      logFormat: output.logFormat,
      outputs: [output]
    )
  }

  private var interactionEvent: AutoLogEvent {
    makeEvent(
      location: "App/CheckoutView.swift:30:5",
      declaration: "button(\"Pay\")",
      source: previewContext,
      result: .success(())
    )
  }

  private var startEvent: AutoLogEvent {
    var event = AutoLogEvent(
      level: LogLevel.start,
      source: previewContext,
      location: "App/CheckoutViewModel.swift:32:5",
      declaration: "func processPayment(amount: Decimal) async",
      parameters: ["amount": "49.99"],
      tags: [output.route]
    )
    event.executionContext = AutoLogExecutionContext(threadLabel: "main", threadID: 0x1001, taskID: "T:MAIN")
    return event
  }

  private var successEvent: AutoLogEvent {
    var event = makeEvent(
      location: "App/CheckoutViewModel.swift:33:5",
      declaration: "func processPayment(amount: Decimal) async",
      source: previewContext,
      parameters: ["amount": "49.99"],
      result: .success("receipt-42"),
      tags: [output.route]
    )
    event.duration = .milliseconds(24)
    return event
  }

  private var failureEvent: AutoLogEvent {
    struct PaymentError: Error, CustomStringConvertible {
      var description: String { "cardDeclined" }
    }

    var event = makeEvent(
      location: "App/CheckoutViewModel.swift:34:5",
      declaration: "func processPayment(amount: Decimal) async throws",
      source: previewContext,
      parameters: ["amount": "49.99"],
      result: .failure(PaymentError()),
      tags: [output.route]
    )
    event.duration = .milliseconds(120)
    return event
  }

  private var firebaseViewModelEvent: AutoLogEvent {
    makeEvent(
      location: "App/AuthViewModel.swift:12:5",
      declaration: "func syncSession() async",
      source: previewContext,
      result: .success("ok"),
      tags: [AutoLogRoute.firebase]
    )
  }

  private var previewContext: SourceContext {
    SourceContext(
      source: AutoLogInteraction.button("Pay"),
      location: "App/CheckoutView.swift:30:5",
      interactionID: "3AC150",
      flowMarker: "🚀"
    )
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
    event.executionContext = AutoLogExecutionContext(threadLabel: "bg", threadID: 0x4AF2, taskID: "T:8C10")
    return event
  }

  private func eventWithContext(_ event: AutoLogEvent) -> AutoLogEvent {
    guard case .failure = event.result, output.errorContextLimit > 0 else { return event }

    var enriched = event
    enriched.errorContext = [
      AutoLogErrorContextEntry(summary: "👆🏼-🚀3AC150 │        │      │ 👆🏼 Pay"),
      AutoLogErrorContextEntry(summary: "👆🏼-🚀3AC150 │        │ main │ ├──🔵 CheckoutViewModel.processPayment(amount: 49.99) async"),
      AutoLogErrorContextEntry(summary: "👆🏼-🚀3AC150 │    8ms │ bg   │ └──🟢 CheckoutRepository.prepareCharge(amount: 49.99)"),
      AutoLogErrorContextEntry(summary: "👆🏼-🚀3AC150 │   24ms │ bg   │ └──🟢 PaymentGateway.authorize(amount: 49.99) async → approved"),
    ]
    enriched.errorContext = Array(enriched.errorContext.suffix(output.errorContextLimit))
    return enriched
  }

  private func matches(_ event: AutoLogEvent) -> Bool {
    output.matches(event)
  }

  private var summaryText: String {
    let eventTypes = output.eventTypes
      .sorted { $0.rawValue < $1.rawValue }
      .map(\.rawValue)
      .joined(separator: ", ")
    let typeFilters = output.typeNameFilters.isEmpty
      ? "all types"
      : output.typeNameFilters.joined(separator: ", ")
    let formatSummary = output.logFormat.mainLine
      .map { ".\($0.rawValue)" }
      .joined(separator: " · ")

    return "route=\(output.route.rawValue) events=[\(eventTypes)] types=\(typeFilters) context=\(output.errorContextLimit) format=\(formatSummary)"
  }
}
