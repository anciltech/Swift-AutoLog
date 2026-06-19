# Integrating with Existing Logging

Add Swift AutoLog to a project that already has logging without replacing the
whole logging stack.

## Overview

Most brownfield apps should use Swift AutoLog for function-boundary
instrumentation and keep their existing destination as an output sink. The
customer-facing setup is:

1. Add the `AutoLog` product.
2. Bootstrap the runtime once with `AutoLog.start()`.
3. Tag app-owned service, view-model, use-case, repository, or data-source
   types with `@AutoLog`.
4. Add one or more sinks for existing backends when events should leave the
   default console path.
5. Use explicit production macro profiles such as
   `@AutoLog(emit: .failures, measure: false)` when the build should prune
   success rows.

```swift
import AutoLog

AutoLog.start()

@AutoLog
struct PaymentService {
  func refreshStatus(id: String) async throws -> PaymentStatus {
    try await api.status(id: id)
  }
}
```

When the existing backend should receive selected events, keep the same tagged
types and add a sink-backed configuration:

```swift
import AutoLog

AutoLog.start(
  configuration: AutoLogConfiguration(
    outputs: [
      AutoLogOutput(
        name: "Console",
        route: .console,
        eventTypes: [.interaction, .success, .failure, .warning]
      ),
      AutoLogOutput(
        name: "Existing Backend",
        route: .splunk,
        eventTypes: [.interaction, .failure, .warning],
        typeNameFilters: ["ViewModel", "Service"],
        errorContextLimit: 10,
        parameterPrivacy: .omit
      )
    ]
  ),
  sinks: [
    ExistingBackendSink()
  ]
)
```

```swift
@AutoLog
struct PaymentService {
  func refreshStatus(id: String) async throws -> PaymentStatus {
    try await api.status(id: id)
  }
}
```

## Choose The Bridge

Use the smallest bridge that matches the app.

| Existing stack | Recommended bridge |
|---|---|
| OSLog-only app that wants Apple's `Logger` directly | Use `@OSLogger` and `@OSLogged` |
| Existing backend plus AutoLog console formatting | Use `AutoLogEventSink` with `AutoLog.start(configuration:sinks:)` |
| Existing backend owns all formatting, routing, privacy, and delivery | Implement `AutoLogger` and pass it to `AutoLog.start(logger:configuration:)` |
| Crashlytics, Sentry, Splunk, Datadog, or similar destination | Model the destination as an `AutoLogEventSink` selected by an `AutoLogOutput.route` |
| Very hot code path | Prefer `@Log` on the specific function, `@Deduplicate`, `@Omit`, `@When`, or explicit `emit:` pruning instead of broad type-level logging |

## Sink Bridge

Use `AutoLogEventSink` when the app wants AutoLog to keep the runtime
configuration, formatting, failure context, and console behavior while also
forwarding selected events.

```swift
import AutoLog

struct ExistingBackendSink: AutoLogEventSink {
  let route: AutoLogRoute = .splunk

  func emit(event: AutoLogEvent, configuration: AutoLogConfiguration) {
    let payload = [
      "type": event.inferredTypeName,
      "function": event.functionName,
      "location": event.shortLocation,
      "outcome": event.outputEventType.rawValue
    ]

    ExistingBackend.shared.send(payload)
  }
}
```

Non-console outputs default to `parameterPrivacy: .omit`. Keep that default for
external telemetry unless a destination has a reviewed allow-list:

```swift
AutoLogOutput(
  name: "Backend",
  route: .splunk,
  eventTypes: [.failure, .warning],
  parameterPrivacy: .allowList(["orderID", "requestID"])
)
```

## Full Logger Bridge

Use `AutoLogger` when the existing logging stack should own the entire event
pipeline.

```swift
import AutoLog

struct ExistingBackendLogger: AutoLogger {
  func emit(event: AutoLogEvent, configuration: AutoLogConfiguration) {
    switch event.result {
    case .success:
      ExistingBackend.shared.breadcrumb(
        "\(event.inferredTypeName).\(event.functionName)"
      )
    case .failure(let error):
      ExistingBackend.shared.record(
        error: error,
        context: event.errorContext.map(\.summary)
      )
    }
  }
}

AutoLog.start(
  logger: ExistingBackendLogger(),
  configuration: AutoLogConfiguration(
    outputs: [
      AutoLogOutput(
        name: "Failures",
        eventTypes: [.failure, .warning],
        parameterPrivacy: .omit
      )
    ]
  )
)
```

## OSLog-First Apps

If the app already standardizes on Apple's `Logger` and does not need the
AutoLog runtime, use the OSLog macro family:

```swift
import AutoLog

@OSLogger
@OSLogged
struct SyncService {
  func refresh() async throws {
    try await api.refresh()
  }
}
```

Use `AutoLogLogger` instead when the app needs route sinks, failure context,
runtime output filtering, SwiftUI interaction sources, or custom `LogFormat`
output.

## Production Profiles

The verified customer-package production path is explicit macro emission:

```swift
@AutoLog(emit: .failures, measure: false)
struct PaymentService {
  func submit(_ payment: Payment) async throws -> Receipt {
    try await api.submit(payment)
  }
}
```

That keeps thrown failures and prunes success rows at macro expansion time.
Use `@AutoLog(emit: [.failures, .warnings], measure: false)` when locally
handled catch-site warnings should also ship.

`AutoLogConfiguration.derivedBuildConfiguration.macroEnvironment` can still be
used by build systems that prove `AUTOLOG_MACRO_EMIT` and
`AUTOLOG_MACRO_MEASURE` reach macro expansion. Verify that in CI before
depending on bare `@AutoLog` for production pruning.

## Customer Smoke Check

The repository includes a customer-shaped fixture that verifies the basic
brownfield path:

```bash
scripts/customer-adoption-smoke.sh
```

It builds a separate package, calls `AutoLog.start(...)`, routes events to an
`AutoLogEventSink`, and verifies both default and explicit failures-only macro
profiles.
