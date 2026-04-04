# ``AutoLog``

A set of macros that support type-wide and per-function logging with ability to customize how logs are handled.

## Overview
There are many situations where logging additional information is helpful. However most of them are neglected as they reqire some boilerplate, this is especially present in bidirectional architectures. Swift AutoLog aims to simplify this by providing macros that can:

* **Annotate all methods within type or extension**

There is no need to annotate each method individually - simply apply the desired annotation to the declaration, and let the magic happen. Standalone functions can also be annotated.

* **Customize how logs are handled**

All macros include the ability to add tags to logged functions, suppress their output or parameters, or exclude the functions entirely from emmiting an event.

* **Use one live runtime snapshot per invocation**

Macro-generated wrappers capture an ``AutoLogRuntime`` snapshot at function entry, so
the same logger and configuration are used consistently for a function's start and
completion even if the companion settings app updates the live configuration while
that function is already running.

* **Capture early exits as structured metadata**

AutoLog can record when a function exits early from `guard`, `if`, `else if`, or `else` branches, while still preserving the final result, error, and timing information. You can also add explicit intent such as optimization or expected control flow.

* **Leverage OSLog support**

Swift AutoLog provides macros that leverage Apple's OSLog framework, eliminating the need to manually create a [`Logger`](https://developer.apple.com/documentation/os/logger) instance, configure subsystems and categories, or log each function individually.

**On top of that**, Swift AutoLog does not bind you into any proprietary logging system - use the logger of your choice without compromising on convenience that comes with macros.

## Topics

### Essentials

- <doc:Usage>
- <doc:LeverageOSLog>
- <doc:CustomizingMacroBehavior>
- <doc:CreatingCustomLoggableInstance>

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
- ``Tag(_:)``
- ``Level(_:)``

### Other macros
- ``osLogger(subsystem:category:)``
- ``AutoLog/earlyExit(_:_:)``
