# Swift AutoLog
[![CI](https://github.com/anciltech/Swift-AutoLog/actions/workflows/ci.yaml/badge.svg?branch=main)](https://github.com/anciltech/Swift-AutoLog/actions/workflows/ci.yaml)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fanciltech%2FSwift-AutoLog%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/anciltech/Swift-AutoLog)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fanciltech%2FSwift-AutoLog%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/anciltech/Swift-AutoLog)

A set of macros that support type-wide and per-function logging with ability to customize how logs are handled.

## Overview
There are many situations where logging additional information is helpful. However most of them are neglected as they require some boilerplate, this is especially present in bidirectional architectures. Swift AutoLog aims to simplify this by providing macros that can:

* **Annotate all methods within type or extension**

There is no need to annotate each method individually - simply apply the desired annotation to the declaration, and let the magic happen. Standalone functions can also be annotated.

* **Customize how logs are handled**

All macros include the ability to add tags to logged functions, suppress their output or parameters, or even exclude the functions entirely from emitting an event.

* **Leverage OSLog support**

Swift AutoLog provides macros that leverage Apple's OSLog framework, eliminating the need to manually create a [`Logger`](https://developer.apple.com/documentation/os/logger) instance, configure subsystems and categories, or log each function individually.

* **Capture early exits as structured metadata**

Swift AutoLog can record when a function exits early from `guard`, `if`, `else if`, or `else` branches, while still preserving the final result, error, and timing information.

**On top of that**, Swift AutoLog does not bind you into any proprietary logging system - use the logger of your choice without compromising on convenience that comes with macros.

## Installation

### Swift Package Manager

Add the dependency to your `Package.swift`:

```swift
.package(url: "https://github.com/anciltech/Swift-AutoLog.git", from: "0.4.0"),
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

### Xcode project

In Xcode:

1. Open `Project > Package Dependencies`
2. Press `+`
3. Paste `https://github.com/anciltech/Swift-AutoLog.git`
4. Add the `AutoLog` product to the app or framework target where you want to use it

When you first build after importing the package, Xcode will prompt you to enable macros from the dependency.

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

Opaque reference-like values are summarized a bit more helpfully in the default compact formatter. If a parameter would otherwise print as only its type name, whether that is `LLA.Frame` or just `Frame`, Swift AutoLog prefers a short `Type.id: ...1234` summary when the value exposes an identifier field, including framework-managed backing fields like `_id`:

```swift
// Before
-> 🟢 InteractionManager.isHovered(frame: LLA.Frame) → false

// After
-> 🟢 InteractionManager.isHovered(frame: Frame.id: ...2341) → false
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

`@OSLogger` introduces a static logger instance, while `@OSLogged` makes methods in that scope loggable automatically.

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
    measureTimingDepths: [2, 3]
  )
)
```

You can still provide a custom logger and advanced store settings when needed:

```swift
AutoLog.start(
  logger: AutoLogLogger(formatter: CompactFormatter(profile: .cleanArchitecture)),
  configuration: AutoLogConfiguration(
    emitStartEvents: false,
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
    measureTimingDepths: [2, 3],
    logFormat: .default
  )
)
```

Future log calls pick up the newest snapshot they read at function entry, while any
function already in flight keeps using the snapshot it captured when it began.

## SwiftUI auto-logging

Swift AutoLog also includes lightweight SwiftUI helpers for common UI interaction logging.

### `Button.log(...)`

Use `Button.log(...)` to emit an interaction event and automatically propagate that source into downstream `@Log` or `@AutoLog` calls:

```swift
Button.log("Save") {
  viewModel.saveTapped()
}
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

## Early exits

Swift AutoLog captures early exits as part of the final event instead of treating them as a separate log line. That means the event still includes:

* the final `result`
* any thrown error
* execution duration
* branch metadata describing the early exit

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

This records that the function exited early from a `guard` branch and still preserves the final `.success(false)` result.

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

If an explicit `AutoLog.earlyExit(...)` call is present in a branch, Swift AutoLog uses that metadata and does not inject another default early-exit record for the same branch.

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

## Learn More
Swift AutoLog offers a wide range of additional features. You can create custom loggers, add tags to captured events for later processing, exclude specific methods from logging, ignore certain parameters (or all of them) from being captured, override the log level for individual events, capture structured early exits, and much more. For usage examples and detailed information, see the [documentation](https://swiftpackageindex.com/anciltech/Swift-AutoLog/main/documentation/autolog).
