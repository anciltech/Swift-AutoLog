# Backend Sink Examples

Route AutoLog events into common brownfield logging stacks.

## Overview

Use ``AutoLogEventSink`` when AutoLog should keep its runtime filtering,
formatting, privacy, and failure-context behavior while forwarding selected
events into an existing destination. Each sink declares the ``AutoLogRoute`` it
listens to, and matching ``AutoLogOutput`` values decide which event kinds pass.

External telemetry outputs should normally keep
``AutoLogParameterPrivacy/omit`` or a reviewed allow-list. Add raw parameters
only when the destination has an explicit privacy review.

## Crashlytics or Firebase

Use the built-in ``AutoLogRoute/firebase`` route for Firebase-style destinations:

```swift
import AutoLog

struct CrashlyticsAutoLogSink: AutoLogEventSink {
  let route: AutoLogRoute = .firebase

  func emit(event: AutoLogEvent, configuration _: AutoLogConfiguration) {
    let breadcrumb = "\(event.inferredTypeName).\(event.functionName)"

    Crashlytics.crashlytics().log(breadcrumb)

    if case .failure(let error) = event.result {
      Crashlytics.crashlytics().record(
        error: error,
        userInfo: [
          "autolog.location": event.shortLocation,
          "autolog.context": event.errorContext.map(\.summary).joined(separator: "\n"),
        ]
      )
    }
  }
}

AutoLog.start(
  configuration: AutoLogConfiguration(
    outputs: [
      AutoLogOutput(
        name: "Crashlytics",
        route: .firebase,
        eventTypes: [.interaction, .failure, .warning],
        typeNameFilters: ["ViewModel", "Service"],
        errorContextLimit: 10,
        parameterPrivacy: .omit
      )
    ]
  ),
  sinks: [CrashlyticsAutoLogSink()]
)
```

## Sentry

Use a custom route for Sentry when the app wants breadcrumbs plus captured
failures:

```swift
import AutoLog

struct SentryAutoLogSink: AutoLogEventSink {
  let route: AutoLogRoute

  init(route: AutoLogRoute = AutoLogRoute("sentry")) {
    self.route = route
  }

  func emit(event: AutoLogEvent, configuration _: AutoLogConfiguration) {
    let breadcrumb = Breadcrumb(level: event.outputEventType == .failure ? .error : .info)
    breadcrumb.category = "autolog"
    breadcrumb.message = "\(event.inferredTypeName).\(event.functionName)"
    breadcrumb.data = [
      "location": event.shortLocation,
      "event": event.outputEventType.rawValue,
    ]
    SentrySDK.addBreadcrumb(breadcrumb)

    if case .failure(let error) = event.result {
      SentrySDK.capture(error: error) { scope in
        scope.setContext(
          value: [
            "function": event.declaration,
            "context": event.errorContext.map(\.summary),
          ],
          key: "autolog"
        )
      }
    }
  }
}

let sentry = AutoLogRoute("sentry")

AutoLog.start(
  configuration: AutoLogConfiguration(
    outputs: [
      AutoLogOutput(
        name: "Sentry",
        route: sentry,
        eventTypes: [.interaction, .failure, .warning],
        errorContextLimit: 10,
        parameterPrivacy: .omit
      )
    ]
  ),
  sinks: [SentryAutoLogSink(route: sentry)]
)
```

## Splunk

Use the built-in ``AutoLogRoute/splunk`` route for Splunk HEC or a similar JSON
collector:

```swift
import AutoLog

struct SplunkAutoLogSink: AutoLogEventSink {
  let route: AutoLogRoute = .splunk
  let client: SplunkClient

  func emit(event: AutoLogEvent, configuration _: AutoLogConfiguration) {
    client.send([
      "event": event.outputEventType.rawValue,
      "type": event.inferredTypeName,
      "function": event.functionName,
      "location": event.shortLocation,
      "tags": event.visibleTags.map { String(describing: $0) }.joined(separator: ","),
    ])
  }
}
```

## Datadog

Use a custom route for Datadog logs or RUM events:

```swift
import AutoLog

let datadog = AutoLogRoute("datadog")

struct DatadogAutoLogSink: AutoLogEventSink {
  let route = AutoLogRoute("datadog")
  let logger: DatadogLogger

  func emit(event: AutoLogEvent, configuration _: AutoLogConfiguration) {
    let attributes = [
      "autolog.event": event.outputEventType.rawValue,
      "autolog.type": event.inferredTypeName,
      "autolog.function": event.functionName,
      "autolog.location": event.shortLocation,
    ]

    switch event.outputEventType {
    case .failure:
      logger.error(event.declaration, attributes: attributes)
    case .warning:
      logger.warn(event.declaration, attributes: attributes)
    default:
      logger.info(event.declaration, attributes: attributes)
    }
  }
}
```

## Existing Logging Facade

If an app already has a logging facade, bridge AutoLog with an app-owned sink so
the base package does not need another logging dependency:

```swift
import AutoLog

struct ExistingLoggerSink: AutoLogEventSink {
  let route = AutoLogRoute("existingLogger")

  func emit(event: AutoLogEvent, configuration _: AutoLogConfiguration) {
    ExistingLogger.shared.log(
      level: event.outputEventType == .failure ? .error : .info,
      message: "\(event.inferredTypeName).\(event.functionName)",
      metadata: [
        "autolog.event": event.outputEventType.rawValue,
        "autolog.type": event.inferredTypeName,
        "autolog.function": event.functionName,
        "autolog.location": event.shortLocation,
      ]
    )
  }
}
```
