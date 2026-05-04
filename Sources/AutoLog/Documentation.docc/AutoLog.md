# ``AutoLog``

A set of macros that support type-wide and per-function logging with ability to customize how logs are handled.

## Overview
There are many situations where logging additional information is helpful. However most of them are neglected as they reqire some boilerplate, this is especially present in bidirectional architectures. Swift AutoLog aims to simplify this by providing macros that can:

* **Annotate all methods within type or extension**

There is no need to annotate each method individually - simply apply the desired annotation to the declaration, and let the magic happen. Standalone functions can also be annotated.

* **Customize how logs are handled**

All macros include the ability to add tags to logged functions, suppress their output or parameters, deduplicate noisy repeated events, emit only interesting return values, or exclude the functions entirely from emmiting an event.

The no-argument ``Omit()`` marker is also accepted on computed properties so
those declarations can opt out explicitly without triggering a compiler error.
Computed properties are not auto-logged today.

* **Use one live runtime snapshot per invocation**

Macro-generated wrappers capture an ``AutoLogRuntime`` snapshot at function entry, so
the same logger and configuration are used consistently for a function's start and
completion even if the companion settings app updates the live configuration while
that function is already running.

* **Capture early exits as structured metadata**

AutoLog can record when a function exits early from `guard`, `if`, `else if`, or `else` branches, and it can also preserve non-returning `if` / `else if` / `else` branch choices that later fall through to the normal function completion path. Final result, error, and timing information remain intact, and you can still add explicit intent such as optimization or expected control flow.

* **Treat handled catches as first-class events**

When a logged function catches an error locally and continues, AutoLog now emits a
warning-level inline event at the `catch` site and keeps a handled-error count on the
parent function event. That preserves the fact that a real failure happened without
misreporting the whole function as thrown.

* **Trace interaction flow across the system**

Interaction sources such as button taps, toggles, timers, and API callbacks propagate through `AutoLog.current`, and each origin receives a short emoji-tagged flow badge so the resulting chain stays easy to follow even when multiple interactions overlap.

* **Leverage OSLog support**

Swift AutoLog provides macros that leverage Apple's OSLog framework, eliminating the need to manually create a [`Logger`](https://developer.apple.com/documentation/os/logger) instance, configure subsystems and categories, or log each function individually.

**On top of that**, Swift AutoLog does not bind you into any proprietary logging system - use the logger of your choice without compromising on convenience that comes with macros.

## Topics

### Essentials

- <doc:Usage>
- <doc:MeasuringPerformance>
- <doc:LeverageOSLog>
- <doc:CustomizingMacroBehavior>
- <doc:CreatingCustomAutoLoggerInstance>

### AutoLog and Log macros

- ``AutoLog(using:)``
- ``Log(using:)``
- ``Log(using:level:omit:tag:)``

### OSLogger, OSLogged and OSLog macros

- ``OSLogger(access:subsystem:category:)``
- ``OSLogged()``
- ``OSLog(level:omit:tag:)``

### Trait macros

- ``Omit()``
- ``Omit(_:)``
- ``Deduplicate(_:)``
- ``When(_:)``
- ``Tag(_:)``
- ``Level(_:)``

### Other macros
- ``osLogger(subsystem:category:)``
- ``AutoLog/earlyExit(_:_:)``
