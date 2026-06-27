# Getting started

Learn how to incorporate the ``AutoLog(using:)`` and ``Log(using:)`` macros into your project, how they work, and much more.

## Overview

This article showcases how to incorporate and use:
* ``AutoLog(using:)``

You will learn how to implicitly annotate each method inside a type or extension, how to provide a custom instance of ``AutoLogger``, and how this instance is propagated.

* ``Log(using:)``

Explore how to capture events from specific functions and override the implicit conformance introduced by ``AutoLog(using:)``.

* ``Omit()``

Opt out of logging and exclude methods from emitting events.

> Code examples used throughout this article are adapted from the former Count Me In example app.
> The first line in each code snippet refers to a file within the app.

## Import the AutoLog library

Add the `https://github.com/anciltech/Swift-AutoLog.git` package at `0.5.1` or
newer and choose the `AutoLog` product in Xcode or Swift Package Manager.

After importing AutoLog for the first time, you will be prompted to enable macros provided by the library.
```swift
// FavoriteFactsModel.swift
import Observation
import AutoLog

// ...
```

## Quick start

The minimum setup is:

1. Add the `AutoLog` product to the target you want to observe.
2. Call ``AutoLog/start(logger:configuration:configurationStore:refreshInterval:)``
   once during app startup. Use `AutoLog.start()` when the default console
   logger and default configuration are enough.
3. Mark the main app-owned types with ``AutoLog(using:)``.

```swift
// MyApp.swift
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

```swift
// PaymentsViewModel.swift
import AutoLog

@AutoLog
@MainActor
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

Start with view models, services, use cases, repositories, and data sources so
the first logs show architecture flow. Use method-level ``Log(using:)`` for
very hot functions, framework adapter callbacks, or isolated events that should
not make an entire type noisy.

## Mark a declaration with the @AutoLog macro
Mark `FavoriteFactsModel` with ``AutoLog(using:)`` annotation. Order in which this annotation is attached does not matter.
```swift
// FavoriteFactsModel.swift

// ...
@AutoLog
@MainActor
@Observable
class FavoriteFactsModel: Identifiable {
  let storageClient: StorageClient
  var facts: [Fact]

  func fetchFavoriteFacts() throws {
    self.facts = try self.storageClient.fetch()
  }

  func deleteFromFavoriteButtonTapped(_ fact: sending Fact) throws {
    try self.storageClient.delete(fact)
  }

  init(
    facts: [Fact] = [],
    storageClient: StorageClient = StorageClient.live
  ) {
    self.facts = facts
    self.storageClient = storageClient

    Task {
      for await _ in NotificationCenter.default.notifications(named: StorageClient.didSave) {
        try self.fetchFavoriteFacts()
      }
    }
  }
}

extension FavoriteFactsModel {
  func deleteAllFavoriteFacts() throws {
    for fact in self.facts {
      try self.storageClient.delete(fact)
    }
  }
}
```

This alone is sufficient for debugging. All methods within the `FavoriteFactsModel` scope are now implicitly marked with the ``Log(using:)`` annotation and will emit an `AutoLogEvent` when invoked. Note that `deleteAllFavoriteFacts`, which is defined within an extension to `FavoriteFactsModel`, lies outside the scope of the type annotation and thus will not be affected.

You can also place ``AutoLog()`` on an extension when that extension contains
the methods you want to instrument. The macro only adds member attributes; it
does not synthesize a companion extension, so extension annotations also work
for private or fileprivate implementation-detail types without requiring a
visibility change.

Type-level ``AutoLog()`` intentionally skips common framework callbacks on
SwiftUI representable adapters and WebKit delegate bridges, such as
`makeUIView`, `updateUIView`, `makeCoordinator`, and `webView(_:didFail:withError:)`.
Those methods tend to be lifecycle noise and can include Objective-C-shaped
signatures such as implicitly unwrapped optionals. Add ``Log()`` directly to a
specific callback only when that framework method is useful signal in your app.

Actors can use type-level ``AutoLog()`` as well. Generated event snapshots are
safe to pass through the sendable logger boundary, while the actor-isolated
method body remains isolated in the original declaration.

By default, ``AutoLog(using:)`` uses the ``AutoLogLogger`` instance. Refer to <doc:CreatingCustomAutoLoggerInstance> for more information about incorporating custom loggers.

For app-wide setup, install a process-local runtime snapshot with
``AutoLog/start(logger:configuration:configurationStore:refreshInterval:)``.
For focused tests or examples, use ``AutoLog/withRuntime(_:operation:)`` or
``AutoLog/withConfiguration(_:operation:)`` to scope a temporary override through
structured concurrency.

```swift
AutoLog.start(
  configuration: AutoLogConfiguration(
    deduplicateWithin: .seconds(1),
    measureTimingDepths: [2, 3],
    normalizedTiming: true,
    failureContextTriggerLimit: 2,
    outputs: [
      AutoLogOutput(
        name: "Console Results",
        route: .console,
        eventTypes: [.warning, .success, .failure],
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
        eventTypes: [.interaction, .failure, .warning],
        typeNameFilters: ["ViewModel", "Service"],
        measureTiming: true,
        timingDepths: [2, 3, 4],
        normalizedTiming: true,
        errorContextLimit: 10,
        logFormat: LogFormat(
          mainLine: [.statusEmoji, .typeName, .dotSeparator, .functionName, .parameters, .timing, .lineNumber]
        ),
        parameterPrivacy: .omit
      )
    ]
  )
)
```

Use `AutoLog.start()` when the default logger and configuration are enough.
Advanced setups can still pass a custom logger, store, or refresh interval.
The default ``CompactFormatter`` keeps small scalar collections inline, but
formats complex arrays, sets, and dictionaries as bounded multi-line previews.
Each visible element gets a short numbered summary, identifier fields are
abbreviated, nested collections collapse to counts, and continuation lines stay
aligned under the compact output columns. Pass
`CompactFormatter(collectionPreviewLimit:)` when a console sink should show more
or fewer entries before the formatter adds `... +N more`.
Single long structured objects keep their full captured description, but the
formatter inserts indentation around nested parentheses, brackets, and commas so
values such as `ScoringDefinition(...)` can be read before adding any length
truncation policy.
For isolated hot paths, add `measure: false` to ``Log(using:level:omit:tag:measure:)``
to suppress generated timing capture for that function, including when the
function routes through a custom ``AutoLogger``. Use `measure: true` when a
specific call site should capture and display timing even if the runtime default
is off. When `measureTimingDefault` is false and a function does not opt in,
the generated wrapper skips its clock sampling work for that call.
If you ship a companion settings screen, matching presets such as "all depths",
"depths 1-2", "depths 2-3", and "depths 3+" keep `measureTimingDepths`
understandable while still mapping directly to the runtime configuration.
When you need more than one destination or view of the same runtime events, add
`outputs`. Each output can target a route like `.console` or `.firebase`,
choose its own `LogFormat`, include or exclude `.start` through `eventTypes`,
filter type names, redact parameters, and attach its own amount of recent
failure context. Untagged events are eligible for every configured output, so a
Crashlytics, Splunk, Datadog, or Sentry sink can receive matching failures and
interactions without Firebase-specific annotations at every call site. Explicit
route tags still narrow a specific function to the tagged route when needed.
When that `LogFormat` includes
`.lineNumber`, the `:42` suffix applies to both standard compact lines and the
interaction trace-tree lines rendered under a source badge.
The companion settings preview uses the same `AutoLogOutput.matches(_:)`
helper as the runtime logger, so route matching, event-kind filtering, and
case-insensitive type-name filters stay aligned while you tune an output
profile.
If you want to embed that editor directly in an iOS 17 or macOS app, the package
also ships `AutoLogSettingsUI` with `AutoLogOutputSettingsView`, which reuses
the same output-profile model, live preview, and code-snippet generation as the
standalone `AutoLogSettings` companion app.
The `AutoLog` runtime itself also supports watchOS 11 or newer; route tags and visible tags
work in watch app code without bringing the settings UI along.
Persisted configurations that still match the package's former single-line
default are automatically migrated to the newer columnar origin/duration/thread
layout the next time the shared configuration store is loaded.
Likewise, `.timing` is now controlled entirely by the `mainLine` element list:
keep it to render elapsed durations, or remove it when a destination should log
the same events without inline timing text.

`AutoLog.start()` installs a console-only default output:

```swift
AutoLogOutput.consoleDefault
```

That default includes `.interaction`, `.start`, `.success`, `.failure`, and
`.warning`. To omit start rows for one destination, remove `.start` from that
destination's `eventTypes` instead of changing a global runtime switch:

```swift
AutoLog.start(
  configuration: AutoLogConfiguration(
    outputs: [
      AutoLogOutput(
        name: "Console",
        route: .console,
        eventTypes: [.interaction, .success, .failure, .warning]
      ),
      AutoLogOutput(
        name: "Crashlytics",
        route: .firebase,
        eventTypes: [.interaction, .failure, .warning],
        typeNameFilters: ["ViewModel"],
        errorContextLimit: 10,
        parameterPrivacy: .omit
      )
    ]
  ),
  sinks: [
    CrashlyticsAutoLogSink()
  ]
)
```

If a single hot path is too noisy, add ``Deduplicate(_:)`` to that function
while leaving the rest of the type untouched:

```swift
// InteractionManager.swift

@AutoLog
struct InteractionManager {
  @Deduplicate(.seconds(1))
  func hover(frame: Frame) -> Bool {
    frame.isHovered
  }
}
```

AutoLog compares the emitted event metadata and suppresses repeated identical
entries inside the configured time window.

## Log TaskGroup children explicitly

`@Log` and `@AutoLog` instrument function boundaries, but `withTaskGroup` child
closures are still just closures. When you want each child to emit its own
start/completion pair, wrap the closure body in ``AutoLog/logTask(_:level:fileID:line:column:operation:)``:

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

Because `AutoLog.logTask(...)` reads the same TaskLocal source context as
macro-generated logs, child tasks keep the interaction badge from the parent
button tap or surrounding `AutoLog.run(...)` scope.

If you want to quantify the overhead of those emitted events, including how
different tag mixes change the hot path, run the dedicated
<doc:MeasuringPerformance> benchmark suite. It compares a plain function against
logged variants that use no tags, visible tags, routing tags, and mixed tag
profiles under the same workload.

## Trace a UI interaction through downstream work

`AutoLog` can attach interaction context to downstream logged calls, whether the
origin is a button tap, toggle change, timer, API callback, or your own custom
``Sourceable`` type.

SwiftUI helpers live in the opt-in `AutoLogSwiftUI` product. Import it in files
that use `Button.log`, `Binding.log`, or lifecycle callback modifiers:

```swift
import AutoLogSwiftUI
```

```swift
Button.log("Save") {
  viewModel.saveTapped()
}
```

`Button.log` mirrors SwiftUI's button initializer families. For custom-label
buttons, keep the first argument as a stable interaction name and use the
native `action:label:` order:

```swift
Button.log("fitness tracker row", action: {
  viewModel.openTracker()
}) {
  HStack {
    Image("icon-apple-health")
    Text("fitness_tracker_apple_health")
    Spacer()
    Image("chevron-right")
  }
}
```

Role-based buttons follow the same order as `Button(role:action:label:)`:

```swift
Button.log("delete tracker row", role: .destructive, action: {
  viewModel.deleteTracker()
}) {
  Label("Delete", systemImage: "trash")
}
```

Text and image-label buttons mirror SwiftUI's title, `systemImage`, and
asset-image initializers. Localized titles and `LocalizedStringResource` values
take an explicit `logName` so logs stay stable while UI copy localizes:

```swift
Button.log("home_button_login", action: {
  viewModel.continue()
})

Button.log(
  LocalizedStringKey("fitness_tracker_apple_health"),
  systemImage: "heart.fill",
  logName: "fitness tracker apple health",
  action: {
    viewModel.openTracker()
  }
)
```

For string literals, `Button.log` follows SwiftUI and treats the literal as a
localized string key, using the same key as the stable interaction name. Dynamic
`String` values use the string-title overload; pass `logName` when the displayed
string and analytics source should differ.

Async actions are supported by the same shape. In Swift 6, callbacks that cross
task boundaries should be `@Sendable`; the async `Button.log` overload keeps the
logging wrapper in one place so reusable row views do not need to hand-write
`Task` and `AutoLogInteraction.button(...).log` at every call site.

The interaction name is intentionally a `String`, not a `LocalizedStringKey`.
Use a stable source identifier such as `"fitness tracker row"` for logs, and
keep localized display text inside the button label.

SwiftUI lifecycle and callback modifiers can also become trace roots without
hand-wrapping the closure:

```swift
.taskLog("Initial Load") {
  await viewModel.load()
}

.taskLog("Reload Search", id: query) {
  await viewModel.search(query)
}

.onAppearLog("Screen Appeared") {
  viewModel.screenAppeared()
}

.onChangeLog("Scene Phase", of: scenePhase) { phase in
  viewModel.scenePhaseChanged(phase)
}

.onReceiveLog(.timer("Refresh Timer"), timer) { _ in
  viewModel.refreshFromTimer()
}

.refreshableLog("Pull to Refresh") {
  await viewModel.refresh()
}

.onSubmitLog(.keyboard("Search Submit")) {
  viewModel.submitSearch()
}
```

String-based lifecycle helpers use ``AutoLogInteraction/system(_:)`` by
default. Pass any ``Sourceable`` value when the origin is better described as
an API callback, timer, keyboard event, gesture, or app-specific custom source.

Every interaction origin gets a compact source-plus-badge prefix such as
`👆🏼-🧵A1B`. The origin event becomes a trace root, and downstream calls
keep that same prefix while using longer branch lengths from the captured
call-site count. The origin is depth 1, the first logged function is depth 2,
and deeper logged calls continue counting from there instead of relying on
type-name suffix matching.
Async interaction scopes preserve the same source context across suspension
points, so work that resumes after `await` still belongs to the original trace.

```text
👆🏼-🧵A1B - 👆🏼 Save [PaymentsView:42]
👆🏼-🧵A1B │ main │       │ ├──🔵 PaymentsViewModel.saveTapped()
👆🏼-🧵A1B │ bg   │ 12ms  │ └───🟢 PaymentService.validate()
👆🏼-🧵A1B │ bg   │ 221ms │ └────🔴 PaymentAPI.submit() → declined [PaymentError]
```

Timing keeps the smallest useful unit, so very short work renders as `ns` or
`µs`, longer work uses `ms`, and multi-second spans use `s`.

For chatty boolean probes where only the positive case matters, add
``When(_:)``:

```swift
// InteractionManager.swift

@AutoLog
struct InteractionManager {
  @When(true)
  func isSelected(frame: Frame) -> Bool {
    selectedFrameIDs.contains(frame.id)
  }
}
```

The function still returns normally, but AutoLog only emits the success event
when the returned value matches the expression you provided. The generated
comparison uses `==`, so optional results and custom `Equatable` return types
work as long as the filter expression has the same comparable shape as the
function's result.

Initializers can be logged explicitly with ``Log(using:)``. Successful and
failable initializer exits emit completion events, while throwing initializers
also capture thrown errors before rethrowing. Swift's member-attribute macro
role does not currently auto-mark initializers, so add ``Log(using:)`` directly
to initializers that should be logged.

## Overriding @AutoLog behavior

Methods within the ``AutoLog(using:)`` scope can also be explicitly marked with the ``Log(using:)`` macro. In such cases, the annotation is overridden and will behave independently of ``AutoLog(using:)``.

```swift
// FavoriteFactsModel.swift

// ...
@AutoLog
@MainActor
@Observable
class FavoriteFactsModel: Identifiable {
  // ...
  func fetchFavoriteFacts() throws {
    self.facts = try self.storageClient.fetch()
  }

  @Log(using: .printer)
  func deleteFromFavoriteButtonTapped(_ fact: sending Fact) throws {
    try self.storageClient.delete(fact)
  }
  // ..
}

```
If we invoke both `fetchFavoriteFacts` and `deleteFromFavoriteButtonTapped`, the first will use the default logger, whereas the second will send an event to the `.printer` logger. This behavior can also be reversed. Refer to <doc:CreatingCustomAutoLoggerInstance> for more information about incorporating custom loggers.

> Arguments provided to the `@AutoLog` macro are implicitly propagated to all methods within the declaration scope, unless explicitly opted out. Initializers need an explicit `@Log(...)` annotation.

## Prune generated event paths

Runtime output filters are useful when a target wants to keep the same
instrumentation but route or display fewer events. They do not reduce the
wrapper code emitted by the macro. In normal app source, keep types marked with
plain `@AutoLog` and let ``AutoLogConfiguration`` define the active output
profile:

```swift
@AutoLog
struct PaymentService {
  func submit(_ payment: Payment) async throws -> Receipt {
    // Runtime configuration decides which events emit for this build or run.
  }
}
```

When a production target should also shrink generated wrapper code, derive a
build profile from that same configuration and export it before compilation:

```swift
let configuration = AutoLogConfiguration(
  outputs: [
    AutoLogOutput(
      name: "Production Failures",
      route: .console,
      eventTypes: [.failure],
      measureTiming: false
    )
  ]
)

let buildConfiguration = configuration.derivedBuildConfiguration
// AUTOLOG_MACRO_EMIT=.failures
// AUTOLOG_MACRO_MEASURE=false
```

Bare `@AutoLog` and `@Log` annotations read `AUTOLOG_MACRO_EMIT` and
`AUTOLOG_MACRO_MEASURE` when explicit macro arguments are absent and those
values are visible to macro expansion. This can let a production build compile
only the selected event paths without adding
`@AutoLog(emit: .failures, measure: false)` across every type. Treat those
environment values as build inputs: when they change, clean the target or make
the values part of the CI cache key so affected macro expansions are rebuilt.
Before relying on this in a customer build, verify that the build system passes
those variables to macro expansion. The repository's customer SwiftPM smoke
fixture currently verifies the explicit `emit:` form because raw environment
variables did not propagate there.

Use ``AutoLogEmission/completions`` to skip start rows while keeping successes
and failures, ``AutoLogEmission/successes`` for success-only probes,
``AutoLogEmission/failures`` for thrown failures, and
``AutoLogEmission/warnings`` for locally handled catch-site diagnostics. Pass
a single case for one generated path or an array such as
`@AutoLog(emit: [.failures, .warnings])` when multiple paths are required.
Explicit `emit:` and `measure:` arguments remain useful for production source,
local overrides, benchmarks, and generated source. Methods that cannot emit any
selected event path, such as nonthrowing methods under `.failures`, are left
uninstrumented.

If the runtime outputs are the desired source of truth, use
``AutoLogConfiguration/derivedBuildConfiguration`` to generate the default
build ceiling from enabled output event types. For example, outputs containing
only `.failure` and `.warning` derive `macroEmitArgument ==
"[.failures, .warnings]"` and a matching `macroEnvironment` dictionary. Route
filters and type-name filters remain runtime matching rules and are not used to
prune generated wrapper paths.

## Omit methods from being logged

Simply change the ``Log(using:)`` annotation to ``Omit()``. In this scenario, an event won’t be emitted when the function is invoked. The ``Omit(_:)`` macro also has an override, which you can learn more about in <doc:CustomizingMacroBehavior>.

```swift
// FavoriteFactsModel.swift

// ...
@AutoLog
@MainActor
@Observable
class FavoriteFactsModel: Identifiable {
  // ...
  @Omit
  func fetchFavoriteFacts() throws {
    self.facts = try self.storageClient.fetch()
  }

  func deleteFromFavoriteButtonTapped(_ fact: sending Fact) throws {
    try self.storageClient.delete(fact)
  }
  // ..
}
```

`@Omit` is also accepted on computed properties as a marker, which is useful
when you want declarations like `@Omit var isCreating: Bool { ... }` to compile
cleanly inside an `@AutoLog` type. Computed properties are not auto-logged, so
the marker does not change runtime behavior yet.

## Passing traits to @Log annotation
The ``Log(using:level:omit:tag:)`` macro supports traits that can be used to tailor its behavior. These traits can also be used used on their own, without ``AutoLog(using:)`` being attached to a scope.

```swift
// FavoriteFactsModel.swift

// ...
extension FavoriteFactsModel {
  @Log(tag: "Deletion")
  func deleteAllFavoriteFacts() throws {
    for fact in self.facts {
      try self.storageClient.delete(fact)
    }
  }
}
```

Upon invocation of `deleteAllFavoriteFacts`, the `"Delete"` tag will be passed along with the event. Learn more about traits in <doc:CustomizingMacroBehavior>.

## Capture early exits and branch paths

`@Log` and `@AutoLog` also capture structured metadata for early exits inside a function body. This includes exits from `guard`, `if`, `else if`, `else`, and `switch` branches when they return or throw before the function reaches its normal end.

```swift
// LayoutEditorService.swift

@Log
func deleteActiveLayout(from collection: LayoutCollection) -> Bool {
  guard collection.layouts.count > 1 else {
    return false
  }

  collection.layouts.removeAll { $0.id == collection.activeLayout.id }
  return true
}
```

In this example, the emitted event still contains the final result (`.success(false)`), duration, tags, and any other captured metadata. In addition, the event records that the function took an early-exit path from a `guard` branch and stores the effective predicate state that led into that exit. The compact formatter renders that annotation as a short visual detail line such as `└── ↘️ !(collection.layouts.count > 1)`.

For composite boolean `guard` expressions, the macro traces the evaluated boolean terms once and preserves Swift's normal short-circuit behavior. When the guard fails, the early-exit annotation shows the failed term or terms instead of repeating the whole condition:

```swift
@Log
func remove(status: OSStatus) -> Bool {
  guard status == errSecSuccess || status == errSecItemNotFound else {
    return false
  }

  return true
}
```

If `status` is neither accepted value, the detail line focuses on the comparisons that failed, such as `└── ↘️ status == errSecSuccess, status == errSecItemNotFound`.

### Add explicit intent to an early exit

When the early exit is expected and meaningful to your domain, you can annotate it with intent metadata using ``AutoLog/earlyExit(_:_:)``.

```swift
// LayoutEditorService.swift

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

The following forms are supported:

```swift
AutoLog.earlyExit(.optimize, "cache hit")
AutoLog.earlyExit(.optimize)
AutoLog.earlyExit()
```

If an explicit `AutoLog.earlyExit(...)` call is present in a branch, the macro uses that metadata and does not inject a second default early-exit record for the same branch. The formatter keeps the effective predicate state first, then appends the explicit intent and optional message when present, for example `└── ↘️ hit • optimize • cache hit`. When intent is `.unknown`, it stays hidden.

### Record non-returning branch choices

AutoLog also records the executed `if`, `else if`, `else`, or `switch` path when the branch continues normally and the function later finishes through its usual completion path.

```swift
// ShortcutManager.swift

@Log
func toggleFramePicker(isVisible: Bool) {
  if isVisible {
    pickerPanel.hide()
  } else {
    pickerPanel.show()
  }
}
```

In this case, the final event still carries the normal success result and duration, and now also includes a branch-path annotation such as `if branch condition=isVisible`. The formatter keeps the annotation focused on the truthy path that actually advanced execution, while the raw event metadata still retains the structural branch kind.

### Handled catches still emit a visible event

AutoLog now also treats local `do` / `catch` recovery as first-class logging data.
When a logged function catches an error and continues, the parent event keeps its real
success or failure semantics, but the catch site emits a separate warning-level inline
event and the parent records how many handled catches occurred.

```swift
@AutoLog
func project() async {
  do {
    try await performMirrorProjection()
  } catch {
    projectionStatus = "Error: \(error.localizedDescription)"
  }
}
```

That means a recovered failure no longer collapses into a single green success row.
You will see the caught error at the catch site, and the final function event will
also include a handled-error annotation so the control-flow story stays honest.
Those catch-site rows still go through the same `emitIfEnabled(...)` path as every
other AutoLog event, so omission rules and duplicate suppression remain consistent.
If the catch uses an explicit binding such as `catch let error`, AutoLog forwards
that bound value to the handled-error event instead of relying only on Swift's
implicit `error` binding.
When failure context is available, the formatter now separates that trail with
`˄` / `˅` dividers, inserts a `💥 Error in Type.function()` marker after the
context list, shows `[1 error handled here]` on the yellow handled-error row,
and keeps the green success row compact with a trailing summary like
`| 1 error handled internally`.

### What gets captured automatically

For each early exit or recorded branch path, AutoLog captures:

* the branch kind (`guard`, `if`, `elseif`, `else`, `switch case`, or `switch default`)
* the evaluated branch condition, when available
* the explicit intent and message, when you provide them
* handled-error warning events emitted from local `catch` blocks
* the final function result or thrown error through the normal `event.result`
* the function duration, just like any other completion path

This keeps branch decisions visible without treating them as automatic failures. A branch may exit early and still be a successful, expected outcome such as `.success(false)` or `.success(nil)`, and a non-returning branch can now remain visible even when the function later completes normally.

Output profiles classify manual ``AutoLog/warning(_:fileID:line:)`` events and
handled-error catch-site rows as `.warning`, so warning rows can be shown or
hidden independently from ordinary successful completions and thrown failures.
