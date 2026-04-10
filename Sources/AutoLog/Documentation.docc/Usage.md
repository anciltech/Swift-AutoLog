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

After importing AutoLog for the first time, you will be prompted to enable macros provided by the library.
```swift
// FavoriteFactsModel.swift
import Observation
import AutoLog

// ...
```

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

This alone is sufficient for debugging. All methods within the `FavoriteFactsModel` scope are now implicitly marked with the ``Log(using:)`` annotation and will emit an `AutoLogEvent` when invoked. Note that `deleteAllFavoriteFacts`, which is defined within an extension to `FavoriteFactsModel`, lies outside the scope of ``AutoLog(using:)`` and thus will not be affected.

When you use editor macro expansion, ``AutoLog(using:)`` also emits an empty companion extension for the attached type. That gives Xcode a concrete type-level expansion to show even when the declaration does not gain visible members of its own, while the real logging behavior still comes from the injected ``Log(using:)`` annotations on functions.

By default, ``AutoLog(using:)`` uses the ``AutoLogLogger`` instance. Refer to <doc:CreatingCustomAutoLoggerInstance> for more information about incorporating custom loggers.

For app-wide setup, install a process-local runtime snapshot with
``AutoLog/start(logger:configuration:configurationStore:refreshInterval:)``.
For focused tests or examples, use ``AutoLog/withRuntime(_:operation:)`` or
``AutoLog/withConfiguration(_:operation:)`` to scope a temporary override through
structured concurrency.

```swift
AutoLog.start(
  configuration: AutoLogConfiguration(
    emitStartEvents: false,
    deduplicateWithin: .seconds(1),
    measureTimingDepths: [2, 3],
    outputs: [
      AutoLogOutput(
        name: "Console Results",
        route: .console,
        eventTypes: [.success, .failure],
        typeNameFilters: ["ViewModel"],
        measureTiming: false,
        errorContextLimit: 10,
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
        errorContextLimit: 10,
        logFormat: LogFormat(
          mainLine: [.statusEmoji, .typeName, .dotSeparator, .functionName, .parameters, .timing, .lineNumber]
        )
      )
    ]
  )
)
```

Use `AutoLog.start()` when the default logger and configuration are enough.
Advanced setups can still pass a custom logger, store, or refresh interval.
If you ship a companion settings screen, matching presets such as "all depths",
"depths 1-2", "depths 2-3", and "depths 3+" keep `measureTimingDepths`
understandable while still mapping directly to the runtime configuration.
When you need more than one destination or view of the same runtime events, add
`outputs`. Each output can target a route like `.console` or `.firebase`,
choose its own `LogFormat`, exclude start events, filter type names, and attach
its own amount of recent failure context. When that `LogFormat` includes
`.lineNumber`, the `:42` suffix applies to both standard compact lines and the
interaction trace-tree lines rendered under a source badge.

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

If you want to quantify the overhead of those emitted events, including how
different tag mixes change the hot path, run the dedicated
<doc:MeasuringPerformance> benchmark suite. It compares a plain function against
logged variants that use no tags, visible tags, routing tags, and mixed tag
profiles under the same workload.

## Trace a UI interaction through downstream work

`AutoLog` can attach interaction context to downstream logged calls, whether the
origin is a button tap, toggle change, timer, API callback, or your own custom
``Sourceable`` type.

```swift
Button.log("Save") {
  viewModel.saveTapped()
}
```

Every interaction origin gets a short flow badge such as `🧵A1B2C3`. The
origin event becomes a trace root, and downstream calls use longer branch
lengths to hint at architectural depth:

```text
👆🏼 Save 🧵A1B2C3
├──🟢 PaymentsViewModel.saveTapped()
├───🟢 PaymentService.validate()                  ⏱ 12ms
└────🔴 PaymentAPI.submit()                       ⏱ 221ms
     └── declined [PaymentError]
```

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
when the returned value matches the expression you provided.

> Initializers are not implicitly marked with the ``Log(using:)`` annotation. Marking them explicitly also has no effect.

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

> Arguments provided to the `@AutoLog` macro are implicitly propagated to all methods within the declaration scope, unless explicitly opted out.

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

`@Log` and `@AutoLog` also capture structured metadata for early exits inside a function body. This includes exits from `guard`, `if`, `else if`, and `else` branches when they return or throw before the function reaches its normal end.

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

In this example, the emitted event still contains the final result (`.success(false)`), duration, tags, and any other captured metadata. In addition, the event records that the function took an early-exit path from a `guard` branch and stores the branch condition.

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

If an explicit `AutoLog.earlyExit(...)` call is present in a branch, the macro uses that metadata and does not inject a second default early-exit record for the same branch.

### Record non-returning branch choices

AutoLog also records the executed `if`, `else if`, or `else` path when the branch continues normally and the function later finishes through its usual completion path.

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

In this case, the final event still carries the normal success result and duration, and now also includes a branch-path annotation such as `if branch condition=isVisible` or `else branch condition=isVisible`.

### What gets captured automatically

For each early exit or recorded branch path, AutoLog captures:

* the branch kind (`guard`, `if`, `elseif`, or `else`)
* the evaluated branch condition, when available
* the explicit intent and message, when you provide them
* the final function result or thrown error through the normal `event.result`
* the function duration, just like any other completion path

This keeps branch decisions visible without treating them as automatic failures. A branch may exit early and still be a successful, expected outcome such as `.success(false)` or `.success(nil)`, and a non-returning branch can now remain visible even when the function later completes normally.
