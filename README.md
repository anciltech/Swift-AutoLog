# Swift AutoLog
[![CI](https://github.com/anciltech/Swift-AutoLog/actions/workflows/ci.yaml/badge.svg?branch=main)](https://github.com/anciltech/Swift-AutoLog/actions/workflows/ci.yaml)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fanciltech%2FSwift-AutoLog%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/anciltech/Swift-AutoLog)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fanciltech%2FSwift-AutoLog%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/anciltech/Swift-AutoLog)

Swift AutoLog is an architectural execution log for Swift apps. It makes behavior observable across architecture, lifecycle, time, and cause: where work moves through the app, how each function executes, when it happens over time, and what triggered it.

A set of macros that support type-wide and per-function logging with ability to customize how logs are handled.

## Overview
There are many situations where logging additional information is helpful. However most of them are neglected as they require some boilerplate, this is especially present in bidirectional architectures. Swift AutoLog aims to simplify this by providing macros that can:

* **Show architectural flow**

Swift AutoLog is designed to make work visible across layers such as `View -> ViewModel -> UseCase -> Repository -> DataSource`, so logs show not just that something happened, but where it moved through the app.

* **Capture execution lifecycle**

Events preserve function start and completion context, along with outcomes such as success, throw, early exit, and branch path decisions, so logs describe how work actually executed instead of only emitting isolated print lines.

* **Attach recent context to failures**

The default `AutoLogLogger` keeps a rolling trail of recent formatted log lines and injects the last few entries into thrown-error events, so failures arrive with the lead-up already attached.

* **Make time visible**

Timing, duration, ordering, and concurrent interleaving stay visible in the emitted output, which makes it easier to reason about slow work, overlap, and async behavior.

* **Preserve causality**

Interaction and system sources such as buttons, toggles, text fields, timers, and API triggers can propagate downstream, so a log line still carries the intent that started the chain.
Each interaction origin also gets a compact source-plus-badge prefix such as `👆🏼-🧵A1B`, making it easier to visually group one button tap or timer tick from another while concurrent work is interleaving.

* **Annotate methods within type or extension**

There is no need to annotate each method individually - simply apply the desired annotation to the declaration, and let the magic happen. Standalone functions and individual initializers can also be annotated explicitly.

* **Customize how logs are handled**

All macros include the ability to add tags to logged functions, suppress their output or parameters, deduplicate noisy repeated events, conditionally omit noisy results or expected errors, or even exclude the functions entirely from emitting an event.

* **Leverage OSLog support**

Swift AutoLog provides macros that leverage Apple's OSLog framework, eliminating the need to manually create a [`Logger`](https://developer.apple.com/documentation/os/logger) instance, configure subsystems and categories, or log each function individually.

* **Capture early exits as structured metadata**

Swift AutoLog can record when a function exits early from `guard`, `if`, `else if`, or `else` branches, while still preserving the final result, error, and timing information.

**On top of that**, Swift AutoLog does not bind you into any proprietary logging system - use the logger of your choice without compromising on convenience that comes with macros.

## Installation

### Swift Package Manager

Add the dependency to your `Package.swift`:

```swift
.package(url: "https://github.com/anciltech/Swift-AutoLog.git", from: "0.5.1"),
```

Then add `AutoLog` to the target that should use the macros:

```swift
.target(
  name: "MyFeature",
  dependencies: [
    .product(name: "AutoLog", package: "Swift-AutoLog")
  ]
)
```

SwiftUI convenience APIs such as `Button.log`, `Binding.log`,
`.onAppearLog`, and `.taskLog` live in the separate `AutoLogSwiftUI` product:

```swift
.target(
  name: "MyApp",
  dependencies: [
    .product(name: "AutoLog", package: "Swift-AutoLog"),
    .product(name: "AutoLogSwiftUI", package: "Swift-AutoLog")
  ]
)
```

Apps that already use Apple's swift-log package can add the optional
`AutoLogSwiftLog` bridge product:

```swift
.target(
  name: "MyApp",
  dependencies: [
    .product(name: "AutoLog", package: "Swift-AutoLog"),
    .product(name: "AutoLogSwiftLog", package: "Swift-AutoLog")
  ]
)
```

The `AutoLog` library product supports iOS 17, macOS, and watchOS 11 or newer. The
runtime uses package-local locking instead of Swift's iOS 18-only
`Synchronization.Mutex`, so the deployment floor is not tied to that newer API.
Once iOS 18 is old enough to be the minimum supported iOS version, the runtime
lock can move back to `Synchronization.Mutex`. Tag handling,
including visible tags and route tags such as `.console`, `.firebase`, or
`.splunk`, is part of the portable runtime behavior and is available in watch
app targets that depend on `AutoLog`.

### Xcode project

In Xcode:

1. Open `Project > Package Dependencies`
2. Press `+`
3. Paste `https://github.com/anciltech/Swift-AutoLog.git`
4. Add the `AutoLog` product to the app or framework target where you want to use it

When you first build after importing the package, Xcode will prompt you to enable macros from the dependency.

## Quick start

The fastest path is deliberately small:

1. Add the `AutoLog` product to the app, framework, or package target you want
   to observe.
2. Call `AutoLog.start()` once during startup.
3. Mark your main app-owned types with `@AutoLog`.

For a SwiftUI app, bootstrap in the app entry point:

```swift
import AutoLog
import SwiftUI

@main
struct MyApp: App {
  init() {
    AutoLog.start()
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
```

Then tag the behavior that explains the app flow:

```swift
import AutoLog

@AutoLog
final class PaymentsViewModel {
  private let service: PaymentService

  init(service: PaymentService) {
    self.service = service
  }

  func submit(orderID: String) async throws {
    try await service.submit(orderID: orderID)
  }
}

@AutoLog
struct PaymentService {
  func submit(orderID: String) async throws {
    try await api.submit(orderID: orderID)
  }
}
```

Start with view models, services, use cases, repositories, and data sources.
For very hot paths or framework adapter callbacks, add `@Log` only where that
specific function is useful signal.

## Add to a project with existing logging

For brownfield apps, keep the existing backend and let Swift AutoLog generate
function-boundary events:

1. Add the `AutoLog` product.
2. Bootstrap once with `AutoLog.start(...)`.
3. Add an `AutoLogEventSink` for the existing backend.
4. Tag app-owned service, view-model, use-case, repository, or data-source
   types with `@AutoLog`.

```swift
import AutoLog

struct ExistingBackendSink: AutoLogEventSink {
  let route: AutoLogRoute = .splunk

  func emit(event: AutoLogEvent, configuration: AutoLogConfiguration) {
    ExistingBackend.shared.send([
      "type": event.inferredTypeName,
      "function": event.functionName,
      "outcome": event.outputEventType.rawValue
    ])
  }
}

AutoLog.start(
  configuration: AutoLogConfiguration(
    outputs: [
      AutoLogOutput(
        name: "Existing Backend",
        route: .splunk,
        eventTypes: [.failure, .warning],
        parameterPrivacy: .omit
      )
    ]
  ),
  sinks: [ExistingBackendSink()]
)
```

Then annotate the behavior you want to observe:

```swift
@AutoLog
struct PaymentService {
  func submit(_ payment: Payment) async throws -> Receipt {
    try await api.submit(payment)
  }
}
```

For production targets that only need thrown failures, the verified customer
path is explicit compile-time emission:

```swift
@AutoLog(emit: .failures, measure: false)
struct PaymentService {
  func submit(_ payment: Payment) async throws -> Receipt {
    try await api.submit(payment)
  }
}
```

See <doc:ExistingLoggingIntegration> for OSLog, swift-log, custom logger, sink,
privacy, backend examples, release checklist, and production-profile guidance.

## Add Swift AutoLog to your project

Import the package in the files where you want to use it:

```swift
import AutoLog
```

### Type-wide logging with `@AutoLog`

Use `@AutoLog` when you want every method in a type to be instrumented automatically:

```swift
import AutoLog
import SwiftData

@AutoLog
@ModelActor
actor SwiftDataClient {
  func save<T: PersistentModel>(_ model: T) throws {
    self.modelContext.insert(model)
    try self.modelContext.save()
  }
}
```

Whenever `save` is invoked, Swift AutoLog emits an event containing metadata such as the source location, declaration, parameters, result, tags, and duration.

`@AutoLog` stays a type-scoped macro: it still instruments methods by injecting `@Log` onto functions. For editor macro expansion, it now also emits an empty companion extension, so expanding `@AutoLog` on a `final class` or another type with no methods still shows a concrete result.

Opaque reference-like values are summarized a bit more helpfully in the default compact formatter. If a parameter would otherwise print as only its type name, whether that is `LLA.Frame` or just `Frame`, Swift AutoLog prefers a short `Type.id: ...1234` summary when the value exposes an identifier field, including framework-managed backing fields like `_id`:

```swift
// Before
-> 🟢 InteractionManager.isHovered(frame: LLA.Frame) → false

// After
-> 🟢 InteractionManager.isHovered(frame: Frame.id: ...2341) → false
```

Collection parameters and return values are also kept readable. Small scalar
arrays stay inline, while complex arrays, sets, and dictionaries render as a
bounded multi-line preview. Each visible element gets a numbered summary,
identifier fields are abbreviated, and nested collections collapse to counts:

```swift
-> 🟢 AppStoreLogic.availableScorings(scorings: [
   1. ScoringDefinition(name: Just Count, version: 2.1.5, stages: 2 items)
   2. ScoringDefinition(name: HIHO, version: 2.1.5, stages: 3 items)
   ... +4 more
])
```

Use `CompactFormatter(collectionPreviewLimit:)` to tune how many collection
entries the formatter shows before adding the `... +N more` line.

Single large structured objects keep their full description, but the formatter
now inserts indentation around nested parentheses, brackets, and commas so a
return value such as `ScoringDefinition(...)` is readable before any length
truncation policy is added:

```swift
-> 🟢 AppStoreLogic.defaultScoring(sport: tennis) → ScoringDefinition(
  name: "Traditional (TieBreak Set)",
  version: "2.1.5",
  description: Optional(
    "Set is won when player wins 6 games, and leads by at least 2."
  ),
  stages: [
    StageDefinition(
      name: "Point",
      rules: [
        RuleDefinition(...)
      ]
    )
  ]
)
```

### Per-function logging with `@Log`

Use `@Log` when you only want to instrument a specific function:

```swift
import AutoLog

struct LayoutEditorService {
  @Log
  func deleteActiveLayout(from collection: LayoutCollection) -> Bool {
    guard collection.layouts.count > 1 else {
      return false
    }

    return true
  }
}
```

When an entire target only needs a narrower event path, prefer compile-time
emission pruning over runtime output filtering:

```swift
import AutoLog

@AutoLog(emit: .failures)
struct PaymentService {
  func submit(_ payment: Payment) async throws -> Receipt {
    // Successes return normally without generating start/success log code.
  }
}
```

The typed values include `.starts`, `.successes`, `.failures`, `.warnings`,
`.completions`, and `.all`. Use a single case for one path, such as
`@AutoLog(emit: .failures)`, or an array for combined policies, such as
`@AutoLog(emit: [.failures, .warnings])`. Runtime
`AutoLogConfiguration` filters still decide which constructed events reach each
output, but `emit:` changes what wrapper code the macro generates in the first
place.

When outputs are the source of truth, derive the build ceiling from the same
configuration:

```swift
let configuration = AutoLogConfiguration(
  outputs: [
    AutoLogOutput(
      name: "Production Console",
      route: .console,
      eventTypes: [.failure, .warning]
    )
  ]
)

configuration.derivedBuildConfiguration.macroEmitArgument
// "[.failures, .warnings]"
```

Route and type-name filters stay runtime-only; output `eventTypes` determine
the default build-time emission ceiling.

For hot paths such as hover polling or selection probes, add `@Deduplicate` to
collapse repeated identical events:

```swift
import AutoLog

@AutoLog
struct InteractionManager {
  @Deduplicate(.seconds(1))
  func hover(frame: Frame) -> Bool {
    frame.isHovered
  }
}
```

For noisy results or expected errors, `@Omit` now supports conditional omission rules:

```swift
import AutoLog

@AutoLog
struct InteractionManager {
  @Omit(.result, containing: "false")
  func isSelected(frame: Frame) -> Bool {
    selectedFrameIDs.contains(frame.id)
  }
}
```

```swift
import AutoLog

@AutoLog
struct AuthService {
  @Omit(.error, containing: ["iamError", "nextAuthStep", "userName"], upToCount: 1)
  func refreshSession() async throws {
    // ...
  }
}
```

`containing:` uses AND semantics after normalization, so every token must match.

### OSLog integration

If you want Swift AutoLog to emit through Apple’s [`Logger`](https://developer.apple.com/documentation/os/logger), use `@OSLogger` and `@OSLogged`:

```swift
import AutoLog
import SwiftData

@OSLogger
@OSLogged
@ModelActor
actor SwiftDataClient {
  func save<T: PersistentModel>(_ model: T) throws {
    self.modelContext.insert(model)
    try self.modelContext.save()
  }
}
```

`@OSLogger` introduces a static logger instance, while `@OSLogged` makes methods in that scope loggable automatically. Like `@AutoLog`, `@OSLogged` also emits an empty companion extension for editor macro expansion so the attached type has a visible expansion result even when it has no methods.

## Manual logs you can use

In addition to the macros, Swift AutoLog exposes manual logging helpers for places where you want an inline event:

* `AutoLog.emit(level, message)`
* `AutoLog.manual(message)`
* `AutoLog.note(message)`
* `AutoLog.update(message)`
* `AutoLog.warning(message)`
* `AutoLog.success(message)`
* `AutoLog.failure(message)`

Example:

```swift
func syncProfile() async throws {
  AutoLog.update("Starting profile sync")
  try await repository.sync()
  AutoLog.success("Profile sync finished")
}
```

You can also attach interaction context to downstream function logs with `AutoLog.run(...)`:

```swift
AutoLog.run(.button("Save")) {
  viewModel.saveTapped()
}
```

If you prefer a more explicit namespace, `AutoLogInteraction` builds the same sources:

```swift
AutoLogInteraction.button("Save").log {
  viewModel.saveTapped()
}
```

For child tasks inside `withTaskGroup`, wrap the closure body in
`AutoLog.logTask(...)` so each child emits its own traced operation:

```swift
let results = await withTaskGroup(of: String.self) { group in
  for name in ["Alpha", "Beta", "Gamma"] {
    group.addTask {
      await AutoLog.logTask("TaskGroup child \(name)") {
        try? await Task.sleep(for: .milliseconds(200))
        return "\(name): done"
      }
    }
  }

  var collected: [String] = []
  for await result in group {
    collected.append(result)
  }
  return collected
}
```

Those child-task logs inherit the current interaction context, so a
`Button.log("Run All")` tap still shows the same trace badge across the parent
function and each task-group child.

## Live runtime configuration

Swift AutoLog keeps a process-local runtime snapshot behind synchronized storage, so
macro-generated `@Log` code can capture one logger/configuration pair at function
entry without tripping Swift 6.2's `nonisolated(unsafe)` warnings.

Use `AutoLog.start()` for the default setup, or pass only the parts you want
to customize:

```swift
AutoLog.start()
```

```swift
AutoLog.start(
  configuration: AutoLogConfiguration(
    emitStartEvents: false,
    deduplicateWithin: .seconds(1),
    measureTimingDepths: [2, 3],
    normalizedTiming: true,
    failureContextTriggerLimit: 2,
    outputs: [
      AutoLogOutput(
        name: "Console Results",
        route: .console,
        eventTypes: [.success, .failure],
        typeNameFilters: ["ViewModel"],
        measureTiming: false,
        errorContextLimit: 10,
        failureContextTriggerLimit: 2,
        logFormat: LogFormat(
          mainLine: [.depthArrow, .statusEmoji, .typeName, .dotSeparator, .functionName, .returnValue]
        )
      ),
      AutoLogOutput(
        name: "Firebase Errors",
        route: .firebase,
        eventTypes: [.failure],
        typeNameFilters: ["ViewModel", "Service"],
        measureTiming: true,
        timingDepths: [2, 3, 4],
        normalizedTiming: true,
        errorContextLimit: 10,
        logFormat: LogFormat(
          mainLine: [.statusEmoji, .typeName, .dotSeparator, .functionName, .parameters, .timing, .lineNumber]
        )
      )
    ]
  )
)
```

When `outputs` is present, each output profile can decide:

* which route it targets, such as `.console`, `.firebase`, or `.splunk`
* which event kinds pass through: interaction, start, success, and/or failure
* which type names should match, using case-insensitive text filters such as `ViewModel`
* whether timing is shown for that output, and optionally which timing depths are visible
* how many recent log summaries are attached when a failure is emitted
* the exact `LogFormat` layout for that destination

The companion settings preview now uses the same `AutoLogOutput.matches(_:)`
rules as `AutoLogLogger`, so route matching, event-kind filtering, and
case-insensitive type-name filters stay aligned between the sample preview and
real emitted output. That settings surface is development tooling; watchOS
support is scoped to the `AutoLog` library product and does not require the
settings UI to run on a watch.

You can still provide a custom logger and advanced store settings when needed:

```swift
AutoLog.start(
  logger: AutoLogLogger(formatter: CompactFormatter(profile: .cleanArchitecture)),
  configuration: AutoLogConfiguration(
    emitStartEvents: false,
    deduplicateWithin: .seconds(1),
    measureTimingDepths: [2, 3]
  )
)
```

If you need to change behavior while the app is running, update the configuration
snapshot atomically:

```swift
AutoLog.updateConfiguration(
  AutoLogConfiguration(
    emitStartEvents: false,
    measureTimingDefault: true,
    deduplicateWithin: .seconds(1),
    measureTimingDepths: [2, 3],
    logFormat: .default
  )
)
```

Future log calls pick up the newest snapshot they read at function entry, while any
function already in flight keeps using the snapshot it captured when it began.

## SwiftUI auto-logging

Swift AutoLog also includes lightweight SwiftUI helpers for common UI
interaction logging. Add the `AutoLogSwiftUI` product and import it in SwiftUI
files that use these helpers:

```swift
import AutoLogSwiftUI
```

### `Button.log(...)`

Use `Button.log(...)` to emit an interaction event and automatically propagate that source into downstream `@Log` or `@AutoLog` calls:

```swift
Button.log("Save") {
  viewModel.saveTapped()
}
```

The interaction event becomes level 1 of a small trace tree. Macro-generated
function events capture the current call-site count, so downstream work uses
longer branch lengths without depending on type-name suffix matching:

```text
👆🏼-🧵A1B - 👆🏼 Save [PaymentsView:42]
👆🏼-🧵A1B │ main │       │ ├──🔵 PaymentsViewModel.saveTapped()
👆🏼-🧵A1B │ bg   │ 12ms  │ └───🟢 PaymentService.validate()
👆🏼-🧵A1B │ bg   │ 221ms │ └────🔴 PaymentAPI.submit() → declined [PaymentError]
```

There is also an async variant:

```swift
Button.log("Refresh") {
  await viewModel.refresh()
}
```

### `Binding.log(...)`

Use `Binding.log(...)` to log value changes from SwiftUI controls:

```swift
Toggle("Dark Mode", isOn: $viewModel.isDarkMode.log(.toggle("Dark Mode")))
```

This is especially helpful for controls driven by `Binding`, where you want changes to carry a source into downstream logged functions.

### Built-in interaction sources

Swift AutoLog includes `InteractionSource` cases for common triggers:

* `.button("Save")`
* `.textField("Search")`
* `.keyboard("Return")`
* `.toggle("Dark Mode")`
* `.gesture("Swipe")`
* `.api("GET /users")`
* `.system("ScenePhase")`
* `.timer("Refresh")`
* `.unknown`

You can also create your own custom source by conforming a type to `Sourceable`.

If you prefer namespaced source builders over enum cases, `AutoLogInteraction.button("Save")` and the other static helpers return the matching `InteractionSource` values.

## Early exits and branch paths

Swift AutoLog captures early exits as part of the final event instead of treating them as a separate log line. It also records the executed `if` / `else if` / `else` branch path when a conditional branch continues normally instead of returning or throwing. That means the event still includes:

* the final `result`
* any thrown error
* execution duration
* branch metadata describing the early exit or executed branch path

For example:

```swift
@Log
func deleteActiveLayout(from collection: LayoutCollection) -> Bool {
  guard collection.layouts.count > 1 else {
    return false
  }

  collection.layouts.removeAll { $0.id == collection.activeLayout.id }
  return true
}
```

This records that the function exited early from a `guard` branch and still preserves the final `.success(false)` result. In the compact formatter, the detail line now shows the effective entered-state instead of the branch keyword, for example `└── ↘️ !(collection.layouts.count > 1)`.

If the early exit is intentional and you want to explain why, annotate it explicitly:

```swift
@Log
func loadProfile(id: Profile.ID) -> Profile? {
  if let cached = cache[id] {
    AutoLog.earlyExit(.optimize, "cache hit")
    return cached
  }

  guard permissions.allowsProfileAccess else {
    AutoLog.earlyExit(.expected, "access denied by policy")
    return nil
  }

  return repository.profile(id: id)
}
```

Supported forms:

```swift
AutoLog.earlyExit(.optimize, "cache hit")
AutoLog.earlyExit(.optimize)
AutoLog.earlyExit()
```

If an explicit `AutoLog.earlyExit(...)` call is present in a branch, Swift AutoLog uses that metadata and does not inject another default early-exit record for the same branch. The compact formatter keeps the effective predicate state first, then appends the explicit intent and optional message when present, for example `└── ↘️ hit • optimize • cache hit`. When intent is `.unknown`, it stays hidden.

When a branch does not exit early, Swift AutoLog records the taken path instead:

```swift
@Log
func toggleFramePicker(isVisible: Bool) {
  if isVisible {
    pickerPanel.hide()
  } else {
    pickerPanel.show()
  }
}
```

That emitted event keeps the normal success result and timing, and adds branch-path metadata such as `if branch condition=isVisible` or `else branch condition=isVisible`.

Handled `catch` blocks now stay visible too. When a logged function recovers from a
local `do` / `catch`, AutoLog emits a warning-level inline event at the catch site and
annotates the final function event with a handled-error count. The outer function can
still finish successfully, but the recovered failure no longer disappears into a single
green result row. Those catch-site events still flow through the normal
`emitIfEnabled(...)` path, so duplicate suppression and omission rules apply in the
same way they do for function-result events. When failure context is attached, the
formatter now separates that trail with `˄` / `˅` dividers, adds an explicit
`💥 Error in Type.function()` marker, places a `[1 error handled here]` badge on the
yellow handled-error row, and keeps recovered-success rows compact with a trailing
summary such as `| 1 error handled internally`.

## Sink routing

By default, every event stays on the built-in console sink. Once you tag a function with one or more route names, only those sinks receive the event.

Add `@Tag` with route names to declare where each call should go:

```swift
@AutoLog(using: logger)
struct AuditTrailService {
  @Tag(.console, .splunk)
  func uploadAuditSnapshot() async throws {
    // Console + Splunk
  }

  @Tag(.splunk)
  func uploadBackgroundHeartbeat() {
    // Splunk only, console is skipped
  }
}
```

Attach custom sinks when you start AutoLog:

```swift
struct SplunkSink: AutoLogEventSink {
  let route: AutoLogRoute = .splunk
  func emit(event: AutoLogEvent, configuration: AutoLogConfiguration) {
    // forward to Splunk
  }
}

AutoLog.start(
  logger: AutoLogLogger(
    formatter: CompactFormatter(),
    sinks: [SplunkSink()]
  )
)
```

See <doc:CreatingCustomAutoLoggerInstance> for a complete walkthrough including custom `AutoLogger` conformance and level integration.

## Replacing existing logs

Swift AutoLog works best when it becomes the default path for function tracing and ad-hoc diagnostics.

### Replace `print` and ad-hoc debug output

You can usually replace:

```swift
print("Saving layout")
print("Cache hit")
```

with:

```swift
AutoLog.update("Saving layout")
AutoLog.note("Cache hit")
```

### Remove manual entry/exit logging from instrumented functions

If a function is annotated with `@Log` or lives under `@AutoLog`, you usually do not need separate manual logs for:

* function start
* function success
* thrown errors
* return values
* timing

Those are already captured by the macro-generated event.

### Keep manual logs for meaningful domain milestones

Inline manual logs are still useful for:

* major state transitions inside a long function
* external system checkpoints
* user-visible milestones
* explicit early-exit intent with `AutoLog.earlyExit(...)`

As a rule of thumb:

* use `@Log` / `@AutoLog` for function boundaries
* use `AutoLog.update(...)` or `AutoLog.note(...)` for meaningful internal milestones
* remove noisy `print`, duplicate `Logger.info`, and repetitive “entered function” style logs once the macro is in place

## Measuring performance

The package now includes `AutoLogPerformanceTests`, a focused benchmark suite
that compares the same function body across:

* a plain baseline with no logging
* `@Log` without tags
* `@Log` with visible string tags
* `@Log` with routing tags such as `.splunk` and `.firebase`
* `@Log` with mixed visible and routing tags

The benchmark uses a logger that exercises the same formatting and route checks
as production `AutoLogLogger` code while discarding final output. That keeps the
results comparable across tag profiles without letting console I/O dominate the
numbers.

Run it from the package root or parent workspace:

```bash
swift test --package-path AutoLogSourceCode/swift-autolog --filter AutoLogPerformanceTests
```

For deeper analysis, start with Xcode Instruments' **Time Profiler** template.
It gives the clearest picture of where the overhead sits inside the logged
function path, especially `AutoLogEvent` creation, `CompactFormatter`, and route
filtering. A matching CLI capture looks like this:

The default compact layout uses a shared precomputed format plan when the
formatter reads `AutoLogConfiguration.logFormat`, so the common dynamic-settings
path does not rebuild default column and inline-element metadata for each event.

```bash
xcrun xctrace record \
  --template 'Time Profiler' \
  --output /tmp/AutoLogPerformance.trace \
  --launch -- \
  swift test \
    --package-path AutoLogSourceCode/swift-autolog \
    --filter AutoLogPerformanceTests/testLoggedFunctionWithMixedTags
```

Use the **Logging** Instruments template as a second pass if you specifically
want to inspect OSLog delivery volume after you understand the in-process cost.

## Learn More
Swift AutoLog offers a wide range of additional features. You can create custom loggers, add tags to captured events for later processing, exclude specific methods from logging, ignore certain parameters (or all of them) from being captured, override the log level for individual events, capture structured early exits, and much more. For usage examples and detailed information, see the [documentation](https://swiftpackageindex.com/anciltech/Swift-AutoLog/main/documentation/autolog).
