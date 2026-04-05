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

> Code examples used throughout this article are part of the example app [Count Me In](https://github.com/23122K/swift-loggable/tree/main/Examples/CountMeIn)
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

By default, ``AutoLog(using:)`` uses the ``AutoLogLogger`` instance. Refer to <doc:CreatingCustomLoggableInstance> for more information about incorporating custom loggers.

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
    measureTimingDepths: [2, 3]
  )
)
```

Use `AutoLog.start()` when the default logger and configuration are enough.
Advanced setups can still pass a custom logger, store, or refresh interval.

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
If we invoke both `fetchFavoriteFacts` and `deleteFromFavoriteButtonTapped`, the first will use the default logger, whereas the second will send an event to the `.printer` logger. This behavior can also be reversed. Refer to <doc:CreatingCustomLoggableInstance> for more information about incorporating custom loggers.

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

## Capture early exits

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

### What gets captured automatically

For each early exit, AutoLog captures:

* the branch kind (`guard`, `if`, `elseif`, or `else`)
* the evaluated branch condition, when available
* the explicit intent and message, when you provide them
* the final function result or thrown error through the normal `event.result`
* the function duration, just like any other completion path

This keeps early exits visible without treating them as automatic failures. A branch may exit early and still be a successful, expected outcome such as `.success(false)` or `.success(nil)`.
