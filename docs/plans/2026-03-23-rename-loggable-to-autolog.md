# Rename Loggable → AutoLog* Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rename all `Loggable`-prefixed public symbols to consistent `AutoLog`/`AutoLogger` names, and update the three `TokenSyntax` cases that generate macro-expanded code to match.

**Architecture:** Pure rename — zero behavior changes. Every public type, every local variable name emitted by macros, and every internal macro protocol gets a new name. Files are renamed on disk to match. The `TokenSyntax` enum cases are the highest-risk touch point: they drive the *strings* emitted into macro-expanded Swift code, so they must be updated atomically with the public types.

**Tech Stack:** Swift 6, SwiftSyntax macros, SPM, XCTest/Swift Testing

---

## Rename Mapping

| Old name | New name | Kind |
|---|---|---|
| `Loggable` | `AutoLogger` | public protocol |
| `LoggableLogger` | `AutoLogLogger` | public struct |
| `LoggableEvent` | `AutoLogEvent` | public struct |
| `LoggableFormatter` | `AutoLogFormatter` | public protocol |
| `LoggableSource` | `AutoLogSource` | public enum |
| `LoggableMacro` | `AutoLogMacro` | internal protocol (macro) |
| `LoggableAttributeMacro` | `AutoLogAttributeMacro` | internal protocol (macro) |
| `loggable` (local var in macro output) | `autoLogger` | emitted identifier string |

## File Rename Mapping

| Old path | New path |
|---|---|
| `Sources/AutoLog/Loggable.swift` | `Sources/AutoLog/AutoLogger.swift` |
| `Sources/AutoLog/LoggableFormatter.swift` | `Sources/AutoLog/AutoLogFormatter.swift` |
| `Sources/AutoLog/LoggableSource.swift` | `Sources/AutoLog/AutoLogSource.swift` |
| `Sources/AutoLog/LoggableSource+SwiftUI.swift` | `Sources/AutoLog/AutoLogSource+SwiftUI.swift` |
| `Sources/AutoLogMacro/Macros/LoggableMacro.swift` | `Sources/AutoLogMacro/Macros/AutoLogMacro.swift` |
| `Sources/AutoLogMacro/Macros/LoggableAttributeMacro.swift` | `Sources/AutoLogMacro/Macros/AutoLogAttributeMacro.swift` |
| `Tests/AutoLogTests/LoggableTests.swift` | `Tests/AutoLogTests/AutoLoggerTests.swift` |
| `Tests/AutoLogTests/Mocks/Loggable+Mock.swift` | `Tests/AutoLogTests/Mocks/AutoLogger+Mock.swift` |

---

### Task 1: Rename and rewrite `AutoLogger.swift` (was `Loggable.swift`)

**Files:**
- Delete: `Sources/AutoLog/Loggable.swift`
- Create: `Sources/AutoLog/AutoLogger.swift`

**Step 1: Write the new file**

```swift
#if canImport(OSLog)
@_exported public import OSLog
#endif

/// A protocol that provides instances of conforming types with the ability to
/// handle emitted events.
public protocol AutoLogger: Sendable {
  /// Handle an emitted event.
  ///
  /// Events are currently emitted in the following cases:
  ///   - When the function completes successfully
  ///   - When the function throws an error.
  ///
  func emit(event: AutoLogEvent)
}

/// A type representing captured metadata from an invoked function.
public struct AutoLogEvent: @unchecked Sendable, CustomStringConvertible, CustomDebugStringConvertible {
  /// The logging level associated with the event.
  public let level: (any Levelable)?

  /// The interaction source that triggered this event, if any.
  public let source: (any Sourceable)?

  /// The source location of the invoked function.
  public let location: String

  /// A representation of a function's name and return
  /// type, excluding parameters and body.
  public let declaration: String

  /// A set of arguments passed to a function, associated
  /// with their parameter labels.
  public var parameters: [String: Any]

  /// The result of the function.
  public var result: Result<Any, any Error>

  /// The collection of tags associated with the event.
  public let tags: [any Taggable]

  /// The measured execution duration of the function, when timing is enabled.
  /// `nil` when `@Log(measure: false)` suppresses timing at compile time.
  public var duration: Duration?

  /// `true` when the function was explicitly annotated with `@Log(measure: true)`,
  /// allowing the formatter to show timing even when the global default is off.
  public var isMeasuredExplicitly: Bool

  public var description: String {
    """
    source: \(source.map { String(describing: $0) } ?? "nil")
    location: \(location)
    declaration: \(declaration)
    parameters: \(parameters)
    result: \(result)
    tags: \(tags)
    """
  }

  public var debugDescription: String {
    """
    level: \(String(describing: level))
    source: \(source.map { String(describing: $0) } ?? "nil")
    location: \(location)
    declaration: \(declaration)
    parameters: \(parameters)
    result: \(result)
    tags: \(tags)
    duration: \(duration.map { String(describing: $0) } ?? "nil")
    """
  }

  /// Initializes an instance that aggregates metadata captured at
  /// the time of function invocation.
  public init(
    level: (any Levelable)? = nil,
    source: (any Sourceable)? = nil,
    location: String,
    declaration: String,
    parameters: [String: Any] = [:],
    result: Result<Any, any Error> = .success(()),
    tags: [any Taggable] = [],
    isMeasuredExplicitly: Bool = false
  ) {
    self.level = level
    self.source = source
    self.location = location
    self.declaration = declaration
    self.parameters = parameters
    self.result = result
    self.tags = tags
    self.duration = nil
    self.isMeasuredExplicitly = isMeasuredExplicitly
  }

  /// A copy of this event representing the function's start, with `.start` level
  /// and default void result. Used by `emitStart(event:)` on `AutoLogger`.
  public var asStartEvent: AutoLogEvent {
    AutoLogEvent(
      level: LogLevel.start,
      source: source,
      location: location,
      declaration: declaration,
      parameters: parameters,
      result: .success(()),
      tags: tags
    )
  }
}

// TODO: 23122K - Consider using swift-log as a fallback when not running on Apple platforms
/// A default `AutoLogger` implementation that
/// uses a ``Logger`` instance to log to the default subsystem.
public struct AutoLogLogger: AutoLogger {
  /// The logger instance used for logging.
  let logger: Logger
  let formatter: any AutoLogFormatter

  /// Logs captured event metadata to the default subsystem.
  public func emit(event: AutoLogEvent) {
    let message = formatter.format(event: event)
    if let level = event.level as? OSLogType {
      self.logger.log(level: level, "\(message)")
    } else {
      self.logger.log(level: event.result.isSuccess ? .info : .error, "\(message)")
    }
  }

  // NOTE: @_spi(Experimental) intentionally removed — using it with @Logged(using:) in
  // Swift 6.2.4 triggers a compiler ICE (ConstraintWalker crash during ResolveMacroRequest).
  // Restore once rdar://FB17xxx / swift-front-end crash is fixed upstream.
  /// Creates a new instance of this type to serve as the default handler
  /// for emitted events.
  public init(
    logger: Logger = Logger(),
    formatter: any AutoLogFormatter = CompactFormatter()
  ) {
    self.logger = logger
    self.formatter = formatter
  }
}

extension AutoLogger {
  /// Emits a start event (🔵) for the given event, respecting the global
  /// `AutoLogSettingsStorage.emitStartEvents` flag.
  ///
  /// Called automatically by macro-generated code at function entry.
  public func emitStart(event: AutoLogEvent) {
    guard AutoLogSettingsStorage.emitStartEvents else { return }
    emit(event: event.asStartEvent)
  }
}

extension AutoLogger where Self == AutoLogLogger {
  /// A default logger instance. Logs to default subsystem.
  public static var logger: Self { AutoLogLogger() }
}

extension Logger: AutoLogger {
  // Uses event.description (verbose multi-line format) intentionally.
  // This conformance supports the @OSLog / @OSLogged macro path.
  // Formatter-based output is only available via AutoLogLogger.
  public func emit(event: AutoLogEvent) {
    if let level = event.level as? OSLogType {
      self.log(level: level, "\(String(describing: event))")
    } else {
      self.log(level: event.result.isSuccess ? .info : .error, "\(String(describing: event))")
    }
  }
}

extension Result {
  fileprivate var isSuccess: Bool {
    guard case .success = self
    else { return false }
    return true
  }
}
```

**Step 2: Delete the old file**

```bash
rm Sources/AutoLog/Loggable.swift
```

**Step 3: Verify it was created / deleted**

```bash
ls Sources/AutoLog/AutoLogger.swift
ls Sources/AutoLog/Loggable.swift  # should fail
```

---

### Task 2: Rename and rewrite `AutoLogFormatter.swift` (was `LoggableFormatter.swift`)

**Files:**
- Delete: `Sources/AutoLog/LoggableFormatter.swift`
- Create: `Sources/AutoLog/AutoLogFormatter.swift`

**Step 1: Write the new file**

Replace every occurrence of:
- `LoggableFormatter` → `AutoLogFormatter`
- `LoggableEvent` → `AutoLogEvent`

The full updated content:

```swift
/// A type that formats an ``AutoLogEvent`` into a printable string.
public protocol AutoLogFormatter: Sendable {
  func format(event: AutoLogEvent) -> String
}

/// A compact formatter that renders events in a readable, structured format.
// ... (all the CompactFormatter implementation, with LoggableEvent → AutoLogEvent throughout)
```

The only changes in this file are:
- Line 2: `public protocol LoggableFormatter` → `public protocol AutoLogFormatter`
- Line 4: `func format(event: LoggableEvent)` → `func format(event: AutoLogEvent)`
- Line 47: `public struct CompactFormatter: LoggableFormatter` → `public struct CompactFormatter: AutoLogFormatter`
- Line 59: `public func format(event: LoggableEvent)` → `public func format(event: AutoLogEvent)`
- Line 179: `private func isStartEvent(_ event: LoggableEvent)` → `private func isStartEvent(_ event: AutoLogEvent)`
- Line 184: `private func emoji(for event: LoggableEvent,` → `private func emoji(for event: AutoLogEvent,`
- Line 209: `private func timingSuffix(for event: LoggableEvent,` → `private func timingSuffix(for event: AutoLogEvent,`
- Line 231: `private func sourceAttributionLine(for event: LoggableEvent)` → `private func sourceAttributionLine(for event: AutoLogEvent)`

**Step 2:** Perform the renames with sed (or Edit tool):

```bash
cd /Users/genesis/Coding/XCode/Other/LoggingExample/LoggableSourceCode/swift-loggable
cp Sources/AutoLog/LoggableFormatter.swift Sources/AutoLog/AutoLogFormatter.swift
# Then edit AutoLogFormatter.swift: replace LoggableFormatter→AutoLogFormatter, LoggableEvent→AutoLogEvent
rm Sources/AutoLog/LoggableFormatter.swift
```

---

### Task 3: Rename and rewrite `AutoLogSource.swift` (was `LoggableSource.swift`)

**Files:**
- Delete: `Sources/AutoLog/LoggableSource.swift`
- Create: `Sources/AutoLog/AutoLogSource.swift`

**Changes:**
- `public enum LoggableSource` → `public enum AutoLogSource`
- `any Loggable = LoggableLogger()` → `any AutoLogger = AutoLogLogger()`
- All three `LoggableEvent(...)` constructor calls → `AutoLogEvent(...)`
- All doc comments referencing `LoggableSource` → `AutoLogSource`
- `LoggableSource.current` → `AutoLogSource.current` (in doc comments)

Full updated content of `AutoLogSource.swift`:

```swift
/// A `Sourceable` wrapper that pairs an interaction source with the call-site
/// location where it was activated. Stored in `AutoLogSource.current` so that
/// downstream `@Logged` function events can include the attribution line
/// (`↖ 👆🏼 Run [AsyncExamplesView:42]`).
///
/// `SourceContext` conforms to `Sourceable` by delegating all protocol
/// requirements to the wrapped source, so existing code reading
/// `AutoLogSource.current?.emoji` / `.label` continues to work unchanged.
public struct SourceContext: Sourceable, Sendable {
  /// The underlying interaction source (e.g., `InteractionSource.button("Run")`).
  public let source: any Sourceable
  /// The call-site location in `fileID:line:column` format.
  public let location: String

  public init(source: any Sourceable, location: String) {
    self.source = source
    self.location = location
  }

  public var emoji: String       { source.emoji }
  public var label: String?      { source.label }
  public var description: String { source.description }
}

/// Manages the current interaction source via TaskLocal and emits
/// standalone interaction events when sources are activated.
public enum AutoLogSource {
  /// The current interaction source context, automatically propagated
  /// through structured concurrency (async/await, TaskGroup).
  @TaskLocal public static var current: SourceContext?

  /// The logger used to emit standalone interaction events.
  /// Defaults to `AutoLogLogger()`. Set this to customize
  /// where interaction events are logged.
  ///
  /// - Important: Set this property during app initialization only,
  ///   before any concurrent calls to ``run(_:fileID:line:column:operation:)``.
  ///   Mutating it concurrently with `run()` calls is a data race.
  public static nonisolated(unsafe) var logger: any AutoLogger = AutoLogLogger()

  // MARK: - Interaction source activation

  /// Emits a standalone interaction event and runs the operation
  /// with the source set on the TaskLocal.
  @discardableResult
  public static func run<T>(
    _ source: any Sourceable,
    fileID: String = #fileID,
    line: Int = #line,
    column: Int = #column,
    operation: () throws -> T
  ) rethrows -> T {
    let locationString = "\(fileID):\(line):\(column)"
    logger.emit(event: AutoLogEvent(
      source: source,
      location: locationString,
      declaration: source.description
    ))
    return try $current.withValue(SourceContext(source: source, location: locationString)) {
      try operation()
    }
  }

  /// Async variant of ``run(_:fileID:line:column:operation:)``.
  @discardableResult
  public static func run<T>(
    _ source: any Sourceable,
    fileID: String = #fileID,
    line: Int = #line,
    column: Int = #column,
    operation: () async throws -> T
  ) async rethrows -> T {
    let locationString = "\(fileID):\(line):\(column)"
    logger.emit(event: AutoLogEvent(
      source: source,
      location: locationString,
      declaration: source.description
    ))
    return try await $current.withValue(SourceContext(source: source, location: locationString)) {
      try await operation()
    }
  }

  // MARK: - Manual inline logging

  /// Emits a manual log entry with the given level and message.
  public static func emit(
    _ level: LogLevel = .update,
    _ message: String,
    fileID: String = #fileID,
    line: Int = #line
  ) {
    logger.emit(event: AutoLogEvent(
      level: level,
      source: current?.source,
      location: "\(fileID):\(line)",
      declaration: message,
      parameters: [:]
    ))
  }
}
```

**Step 2:**
```bash
rm Sources/AutoLog/LoggableSource.swift
```

---

### Task 4: Rename `AutoLogSource+SwiftUI.swift` (was `LoggableSource+SwiftUI.swift`)

**Files:**
- Delete: `Sources/AutoLog/LoggableSource+SwiftUI.swift`
- Create: `Sources/AutoLog/AutoLogSource+SwiftUI.swift`

**Changes:** Replace `LoggableSource.run` → `AutoLogSource.run` (two occurrences — sync and async variants).

Full updated content:

```swift
#if canImport(SwiftUI)
import SwiftUI

// MARK: - Button.logged

extension Button where Label == Text {
    /// Creates a button that automatically logs the interaction and
    /// propagates the source to all downstream `@Logged` function calls.
    @MainActor public static func logged(
        _ title: String,
        role: ButtonRole? = nil,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        action: @escaping @MainActor () -> Void
    ) -> some View {
        Button(title, role: role) {
            AutoLogSource.run(
                InteractionSource.button(title),
                fileID: fileID,
                line: line,
                column: column
            ) {
                action()
            }
        }
    }

    /// Async variant of ``logged(_:role:fileID:line:column:action:)``.
    @MainActor public static func logged(
        _ title: String,
        role: ButtonRole? = nil,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        action: @escaping @Sendable () async -> Void
    ) -> some View {
        Button(title, role: role) {
            Task {
                await AutoLogSource.run(
                    InteractionSource.button(title),
                    fileID: fileID,
                    line: line,
                    column: column
                ) { @Sendable in
                    await action()
                }
            }
        }
    }
}

// MARK: - Binding.logged

extension Binding {
    /// Returns a new binding that logs interactions when the value is set,
    /// propagating the source to all downstream `@Logged` function calls.
    @MainActor public func logged(
        _ source: InteractionSource,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Binding {
        logged(source as any Sourceable, fileID: fileID, line: line, column: column)
    }

    /// Returns a new binding that logs interactions when the value is set,
    /// using any custom ``Sourceable`` type.
    @MainActor public func logged(
        _ source: any Sourceable,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) -> Binding {
        let current = self
        return Binding(
            get: { current.wrappedValue },
            set: { newValue in
                AutoLogSource.run(
                    source,
                    fileID: fileID,
                    line: line,
                    column: column
                ) {
                    current.wrappedValue = newValue
                }
            }
        )
    }
}

#endif
```

**Step 2:**
```bash
rm Sources/AutoLog/LoggableSource+SwiftUI.swift
```

---

### Task 5: Update `LoggableDefaults.swift` and `Macros.swift`

**Files:**
- Modify: `Sources/AutoLog/LoggableDefaults.swift`
- Modify: `Sources/AutoLog/Macros.swift`

**`LoggableDefaults.swift` changes:**

Line 106: `extension Loggable where Self == LoggableLogger {`
→ `extension AutoLogger where Self == AutoLogLogger {`

Lines 108, 113: `LoggableLogger(formatter: ...)` → `AutoLogLogger(formatter: ...)`

**`Macros.swift` changes:**

Every occurrence of `any Loggable` → `any AutoLogger` (appears in `@Logged` and `@Log` macro overloads).
Every occurrence of `LoggableLogger` → `AutoLogLogger` (appears in the concrete overloads).

Specific line changes in `Macros.swift`:
- Line 148: `public macro Logged(using loggable: any Loggable)` → `public macro Logged(using loggable: any AutoLogger)`
- Line 154: `public macro Logged(architecture loggable: any Loggable)` → `public macro Logged(architecture loggable: any AutoLogger)`
- Line 162: `public macro Logged(using loggable: LoggableLogger)` → `public macro Logged(using loggable: AutoLogLogger)`
- Line 168: `public macro Logged(architecture loggable: LoggableLogger)` → `public macro Logged(architecture loggable: AutoLogLogger)`
- Line 216: `public macro Log(using loggable: any Loggable)` → `public macro Log(using loggable: any AutoLogger)`
- Line 222: `public macro Log(architecture loggable: any Loggable)` → `public macro Log(architecture loggable: any AutoLogger)`
- Line 230: `public macro Log(using loggable: LoggableLogger)` → `public macro Log(using loggable: AutoLogLogger)`
- Line 236: `public macro Log(architecture loggable: LoggableLogger)` → `public macro Log(architecture loggable: AutoLogLogger)`
- Lines 250, 260: `using loggable: any Loggable` → `using loggable: any AutoLogger`
- Lines 264, 269: `using loggable: LoggableLogger` → `using loggable: AutoLogLogger`
- Lines 283, 295: `architecture loggable: LoggableLogger` → `architecture loggable: AutoLogLogger`
- Doc comments referencing `Loggable` → `AutoLogger`

Use replace_all in Edit tool for the renames to catch every instance:
1. `LoggableLogger` → `AutoLogLogger` (replace_all)
2. `any Loggable` → `any AutoLogger` (replace_all)

---

### Task 6: Rename `TokenSyntax.swift` cases and update `AutoLogMacro.swift` + `AutoLogAttributeMacro.swift`

**Files:**
- Modify: `Sources/AutoLogMacro/Extensions/TokenSyntax.swift`
- Delete: `Sources/AutoLogMacro/Macros/LoggableMacro.swift`
- Create: `Sources/AutoLogMacro/Macros/AutoLogMacro.swift`
- Delete: `Sources/AutoLogMacro/Macros/LoggableAttributeMacro.swift`
- Create: `Sources/AutoLogMacro/Macros/AutoLogAttributeMacro.swift`

**`TokenSyntax.swift` — rename these 4 cases:**

In the `Predefined` enum:
- `case loggable` → `case autoLogger`
- `case Loggable` → `case AutoLogger`
- `case LoggableSource` → `case AutoLogSource`
- `case LoggableEvent` → `case AutoLogEvent`

In the `identifier` computed property, update the matching `case` arms and the string literals:
- `case .loggable:` → `case .autoLogger:` with `TokenSyntax.identifier("autoLogger")`
- `case .Loggable:` → `case .AutoLogger:` with `TokenSyntax.identifier("AutoLogger")`
- `case .LoggableSource:` → `case .AutoLogSource:` with `TokenSyntax.identifier("AutoLogSource")`
- `case .LoggableEvent:` → `case .AutoLogEvent:` with `TokenSyntax.identifier("AutoLogEvent")`

**`AutoLogMacro.swift`** (rename from `LoggableMacro.swift`):
- `protocol LoggableMacro: BodyMacro` → `protocol AutoLogMacro: BodyMacro`

**`AutoLogAttributeMacro.swift`** (rename from `LoggableAttributeMacro.swift`):
- `protocol LoggableAttributeMacro: MemberAttributeMacro` → `protocol AutoLogAttributeMacro: MemberAttributeMacro`

Steps:
```bash
cp Sources/AutoLogMacro/Macros/LoggableMacro.swift Sources/AutoLogMacro/Macros/AutoLogMacro.swift
# Edit AutoLogMacro.swift: rename protocol
rm Sources/AutoLogMacro/Macros/LoggableMacro.swift

cp Sources/AutoLogMacro/Macros/LoggableAttributeMacro.swift Sources/AutoLogMacro/Macros/AutoLogAttributeMacro.swift
# Edit AutoLogAttributeMacro.swift: rename protocol
rm Sources/AutoLogMacro/Macros/LoggableAttributeMacro.swift
```

---

### Task 7: Update all macro implementations that reference renamed internals

These files use `LoggableMacro`, `LoggableAttributeMacro`, `.Loggable`, `.LoggableSource`, `.LoggableEvent`, `.loggable`:

**`Sources/AutoLogMacro/Macros/LogMacro.swift`:**
- `extension LogMacro: LoggableMacro {}` → `extension LogMacro: AutoLogMacro {}`

**`Sources/AutoLogMacro/Macros/LoggedMacro.swift`:**
- `extension LoggedMacro: LoggableAttributeMacro` → `extension LoggedMacro: AutoLogAttributeMacro`

**`Sources/AutoLogMacro/Macros/LoggableMacro.swift` (now `AutoLogMacro.swift`) — internal references:**

In `AutoLogMacro.swift`, these `.predefined(...)` calls reference the renamed cases:
- `.predefined(.loggable)` → `.predefined(.autoLogger)` (2 occurrences: `hook()` and `emit()` and `emitStart()`)
- `.predefined(.Loggable)` → `.predefined(.AutoLogger)` (1 occurrence in `hook()`)
- `.predefined(.LoggableSource)` → `.predefined(.AutoLogSource)` (2 occurrences: `event()` and `rewriteYieldStatement()`)
- `.predefined(.LoggableEvent)` → `.predefined(.AutoLogEvent)` (1 occurrence in `event()`)

Use replace_all in Edit tool on `AutoLogMacro.swift`:
1. `.predefined(.loggable)` → `.predefined(.autoLogger)` (replace_all)
2. `.predefined(.Loggable)` → `.predefined(.AutoLogger)` (replace_all)
3. `.predefined(.LoggableSource)` → `.predefined(.AutoLogSource)` (replace_all)
4. `.predefined(.LoggableEvent)` → `.predefined(.AutoLogEvent)` (replace_all)

**Check other macro files** for any remaining references:
```bash
grep -r "Loggable\|loggable" Sources/AutoLogMacro/ --include="*.swift" -l
```
Fix any remaining occurrences found.

---

### Task 8: Update test files

**Files:**
- Delete: `Tests/AutoLogTests/LoggableTests.swift`
- Create: `Tests/AutoLogTests/AutoLoggerTests.swift`
- Delete: `Tests/AutoLogTests/Mocks/Loggable+Mock.swift`
- Create: `Tests/AutoLogTests/Mocks/AutoLogger+Mock.swift`

**`AutoLogger+Mock.swift`** changes from `Loggable+Mock.swift`:
- `final class MockLogger: Loggable` → `final class MockLogger: AutoLogger`
- `var events: [LoggableEvent]` → `var events: [AutoLogEvent]`
- `func emit(event: LoggableEvent)` → `func emit(event: AutoLogEvent)`
- `init(events: [LoggableEvent] = [])` → `init(events: [AutoLogEvent] = [])`
- `extension Loggable where Self == MockLogger` → `extension AutoLogger where Self == MockLogger`

**`AutoLoggerTests.swift`** changes from `LoggableTests.swift`:
- `LoggableSource.logger` → `AutoLogSource.logger` (2 occurrences)
- `struct LoggableTests` → `struct AutoLoggerTests` (suite name)

No other changes needed — the `@Logged` macro and test bodies are fine as-is.

Steps:
```bash
cp Tests/AutoLogTests/LoggableTests.swift Tests/AutoLogTests/AutoLoggerTests.swift
# Edit AutoLoggerTests.swift
rm Tests/AutoLogTests/LoggableTests.swift

cp Tests/AutoLogTests/Mocks/Loggable+Mock.swift Tests/AutoLogTests/Mocks/AutoLogger+Mock.swift
# Edit AutoLogger+Mock.swift
rm Tests/AutoLogTests/Mocks/Loggable+Mock.swift
```

---

### Task 9: Build verification

**Step 1: Build all targets**

```bash
cd /Users/genesis/Coding/XCode/Other/LoggingExample/LoggableSourceCode/swift-loggable
swift build 2>&1
```

Expected: `Build complete!` with zero errors.

If errors appear, read the error messages and fix them. Common issues to look for:
- Any remaining `LoggableEvent` / `LoggableSource` / `LoggableLogger` / `Loggable` references in source files
- Missing case in `TokenSyntax.Predefined` switch (exhaustiveness error)
- Missing `autoLogger` case
- Any file that imports AutoLog and uses the old names (grep can help: `grep -r "LoggableEvent\|LoggableLogger\|LoggableSource\|: Loggable" Sources/ --include="*.swift"`)

**Step 2: Run the test suite**

```bash
swift test 2>&1
```

Expected: All tests pass. Key tests to watch:
- `AutoLoggerTests` — exercises `AutoLogSource.logger`, `AutoLogEvent`, `AutoLogger` protocol conformance
- `LogMacroTests`, `LoggedMacroTests` — exercise macro expansion which emits `AutoLogEvent`, `AutoLogSource`, `autoLogger`
- `CompactFormatterTests` — exercises `AutoLogEvent` formatting

**Step 3: Verify macro expansion still emits correct identifiers**

The macro tests (`LogMacroTests.swift`, `LoggedMacroTests.swift`) use `assertMacroExpansion` which checks the exact string output. After renaming, the expanded code must reference:
- `autoLogger` (the local `let` binding)
- `AutoLogEvent(...)` (event constructor)
- `AutoLogSource.current` (TaskLocal read)

If macro tests fail with string mismatches, the `TokenSyntax` case changes in Task 6 need to be rechecked.

---

### Task 10: Commit

```bash
cd /Users/genesis/Coding/XCode/Other/LoggingExample/LoggableSourceCode/swift-loggable
git add -A
git status  # verify no unexpected files staged
git commit -m "$(cat <<'EOF'
refactor: rename Loggable* symbols to AutoLog* / AutoLogger

- Loggable protocol → AutoLogger
- LoggableLogger struct → AutoLogLogger
- LoggableEvent struct → AutoLogEvent
- LoggableFormatter protocol → AutoLogFormatter
- LoggableSource enum → AutoLogSource
- Internal macro protocols: LoggableMacro → AutoLogMacro,
  LoggableAttributeMacro → AutoLogAttributeMacro
- TokenSyntax.Predefined cases updated to emit new identifier strings
- All source, macro, and test files renamed and updated

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```
