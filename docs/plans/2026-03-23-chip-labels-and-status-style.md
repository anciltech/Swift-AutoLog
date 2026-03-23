# Chip Labels + Status Style Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Shorten format-chip labels (with hover descriptions) and let users customise the emoji/character rendered for each visual status state.

**Architecture:** Two independent changes. (1) `displayName` values get shorter, `FormatChipView` gains `.help()` for tooltips. (2) A new `StatusStyle` struct is added to `LogFormat` — same pattern as `ArrowStyle` — and `CompactFormatter.emoji(for:)` reads from it instead of `LogLevel.emoji`. `SettingsViewModel` exposes it; `FormatEditorView` gains a "Status" section.

**Tech Stack:** Swift 6, SwiftUI (macOS 15), SPM. `Sources/AutoLog` is the library; `Sources/AutoLogSettings` is the companion executable (launched via `run-settings.sh`).

---

### Task 1: Shorten `displayName` and add hover tooltips

**Files:**
- Modify: `Sources/AutoLog/LogFormat.swift`
- Modify: `Sources/AutoLogSettings/FormatChipView.swift`

**Step 1: Update `displayName` in `LogFormat.Element`**

In `Sources/AutoLog/LogFormat.swift`, find the `displayName` computed property and replace its body:

```swift
public var displayName: String {
  switch self {
  case .depthArrow:       return "Depth"
  case .statusEmoji:      return "Status"
  case .typeName:         return "Type"
  case .functionName:     return "Function"
  case .parameters:       return "Params"
  case .effectSpecifiers: return "Async"
  case .returnValue:      return "Return"
  case .timing:           return "Timing"
  case .lineNumber:       return "Line"
  case .dotSeparator:     return "·"
  case .space:            return "Space"
  case .comma:            return "Comma"
  case .pipe:             return "Pipe"
  case .slash:            return "Slash"
  case .newline:          return "↵"
  }
}
```

**Step 2: Add `.help()` tooltip to `FormatChipView`**

In `Sources/AutoLogSettings/FormatChipView.swift`, find the closing `.overlay(...)` modifier and add `.help` immediately after:

```swift
    .overlay(
      RoundedRectangle(cornerRadius: 7)
        .strokeBorder(border, lineWidth: 1)
    )
    .help(element.elementDescription)
```

**Step 3: Build to confirm zero errors**

```bash
swift build --target AutoLogSettings 2>&1 | grep -E "error:|complete"
```
Expected: `Build complete!`

**Step 4: Commit**

```bash
git add Sources/AutoLog/LogFormat.swift Sources/AutoLogSettings/FormatChipView.swift
git commit -m "feat: shorten chip labels and add hover tooltips"
```

---

### Task 2: Add `StatusStyle` to `LogFormat`

**Files:**
- Modify: `Sources/AutoLog/LogFormat.swift`

**Step 1: Add the `StatusStyle` struct**

Inside `LogFormat`, immediately after the closing `}` of `ArrowStyle`, insert:

```swift
// MARK: - StatusStyle

/// Controls which character/emoji is rendered for each visual status state.
///
/// The five states map every event outcome regardless of source:
/// `LogLevel`, `OSLogType`, or a raw `.failure` result all resolve to one
/// of these five slots before rendering.
///
/// Defaults match the original emoji set:
/// `start` 🔵 · `success` 🟢 · `failure` 🔴 · `warning` 🟡 · `update` 🟣
public struct StatusStyle: Sendable, Codable, Equatable {
  public var start:   String
  public var success: String
  public var failure: String
  public var warning: String
  public var update:  String

  public init(
    start:   String = "🔵",
    success: String = "🟢",
    failure: String = "🔴",
    warning: String = "🟡",
    update:  String = "🟣"
  ) {
    self.start   = start
    self.success = success
    self.failure = failure
    self.warning = warning
    self.update  = update
  }

  /// The default set, matching the original `CompactFormatter` output.
  public static let `default` = StatusStyle()
}

/// The status style used when rendering the ``Element/statusEmoji`` component.
public var statusStyle: StatusStyle
```

**Step 2: Update `init` to accept `statusStyle` with default**

Change the existing `init` from:
```swift
public init(mainLine: [Element], arrowStyle: ArrowStyle = .default) {
  self.mainLine   = mainLine
  self.arrowStyle = arrowStyle
}
```
To:
```swift
public init(
  mainLine:    [Element],
  arrowStyle:  ArrowStyle  = .default,
  statusStyle: StatusStyle = .default
) {
  self.mainLine    = mainLine
  self.arrowStyle  = arrowStyle
  self.statusStyle = statusStyle
}
```

**Step 3: Update `CodingKeys` and `Codable` implementation**

Replace `CodingKeys`:
```swift
private enum CodingKeys: String, CodingKey {
  case mainLine, arrowStyle, statusStyle
}
```

Replace `init(from:)`:
```swift
public init(from decoder: Decoder) throws {
  let c        = try decoder.container(keyedBy: CodingKeys.self)
  mainLine     = try c.decode([Element].self,           forKey: .mainLine)
  arrowStyle   = try c.decodeIfPresent(ArrowStyle.self,  forKey: .arrowStyle)  ?? .default
  statusStyle  = try c.decodeIfPresent(StatusStyle.self, forKey: .statusStyle) ?? .default
}
```

Replace `encode(to:)`:
```swift
public func encode(to encoder: Encoder) throws {
  var c = encoder.container(keyedBy: CodingKeys.self)
  try c.encode(mainLine,    forKey: .mainLine)
  try c.encode(arrowStyle,  forKey: .arrowStyle)
  try c.encode(statusStyle, forKey: .statusStyle)
}
```

**Step 4: Build to confirm zero errors**

```bash
swift build --target AutoLog 2>&1 | grep -E "error:|complete"
```
Expected: `Build complete!`

**Step 5: Commit**

```bash
git add Sources/AutoLog/LogFormat.swift
git commit -m "feat: add StatusStyle to LogFormat with graceful Codable fallback"
```

---

### Task 3: Wire `StatusStyle` into `CompactFormatter`

**Files:**
- Modify: `Sources/AutoLog/LoggableFormatter.swift`

**Step 1: Replace `emoji(for:)` signature and body**

Find:
```swift
private func emoji(for event: LoggableEvent) -> String {
```
Replace the entire method with:
```swift
private func emoji(for event: LoggableEvent, style: LogFormat.StatusStyle) -> String {
  if let logLevel = event.level as? LogLevel {
    switch logLevel {
    case .start:   return style.start
    case .success: return style.success
    case .failure: return style.failure
    case .warning: return style.warning
    case .update:  return style.update
    }
  }
  if case .failure = event.result { return style.failure }
  if let osLevel = event.level as? OSLogType {
    switch osLevel {
    case .error, .fault: return style.failure
    case .default:       return style.warning
    case .info, .debug:  return style.start
    default:             return style.success
    }
  }
  return style.success
}
```

**Step 2: Update the call site**

Find:
```swift
let em         = emoji(for: event)
```
Replace with:
```swift
let em         = emoji(for: event, style: fmt.statusStyle)
```

**Step 3: Build + run tests**

```bash
swift build --target AutoLog 2>&1 | grep -E "error:|complete"
swift test 2>&1 | tail -5
```
Expected: all 141 tests pass (default `StatusStyle` emojis match original hardcoded values).

**Step 4: Commit**

```bash
git add Sources/AutoLog/LoggableFormatter.swift
git commit -m "feat: CompactFormatter uses StatusStyle from LogFormat"
```

---

### Task 4: Add `StatusStyle` tests

**Files:**
- Modify: `Tests/AutoLogTests/CompactFormatterTests.swift`

**Step 1: Add the test suite** (insert after `ArrowStyleTests`):

```swift
@Suite
struct StatusStyleTests {

  @Test func defaultStyle_matchesOriginalEmojis() {
    let s = LogFormat.StatusStyle.default
    #expect(s.start   == "🔵")
    #expect(s.success == "🟢")
    #expect(s.failure == "🔴")
    #expect(s.warning == "🟡")
    #expect(s.update  == "🟣")
  }

  @Test func logFormat_decodesLegacyJsonWithoutStatusStyle() throws {
    let json = #"{"mainLine":["statusEmoji"],"arrowStyle":{"start":"-","repeater":"-","end":">"}}"#
    let format = try JSONDecoder().decode(LogFormat.self, from: Data(json.utf8))
    #expect(format.statusStyle == .default)
  }

  @Test func logFormat_roundTripsStatusStyle() throws {
    let original = LogFormat(
      mainLine: [.statusEmoji],
      statusStyle: LogFormat.StatusStyle(start: "▶", success: "✓", failure: "✗", warning: "!", update: "•")
    )
    let data    = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(LogFormat.self, from: data)
    #expect(decoded.statusStyle == original.statusStyle)
  }

  @Test func compactFormatter_usesCustomSuccessChar() {
    let format = LogFormat(
      mainLine: [.statusEmoji, .functionName],
      statusStyle: LogFormat.StatusStyle(success: "✓")
    )
    let formatter = CompactFormatter(profile: .mvvm, format: format)
    var event = LoggableEvent(
      location: "App/MyViewModel.swift:1:1",
      declaration: "func doWork()"
    )
    event.result   = .success(())
    event.duration = .milliseconds(0)
    let output = formatter.format(event: event)
    #expect(output.contains("✓"))
    #expect(!output.contains("🟢"))
  }

  @Test func compactFormatter_usesCustomFailureChar() {
    let format = LogFormat(
      mainLine: [.statusEmoji, .functionName],
      statusStyle: LogFormat.StatusStyle(failure: "✗")
    )
    let formatter = CompactFormatter(profile: .mvvm, format: format)
    var event = LoggableEvent(
      location: "App/MyViewModel.swift:1:1",
      declaration: "func doWork()"
    )
    event.result   = .failure(NSError(domain: "test", code: 0))
    event.duration = .milliseconds(0)
    let output = formatter.format(event: event)
    #expect(output.contains("✗"))
    #expect(!output.contains("🔴"))
  }
}
```

**Step 2: Run new tests**

```bash
swift test --filter StatusStyleTests 2>&1 | tail -10
```
Expected: all 5 pass.

**Step 3: Run full suite**

```bash
swift test 2>&1 | tail -5
```
Expected: all 146 tests pass.

**Step 4: Commit**

```bash
git add Tests/AutoLogTests/CompactFormatterTests.swift
git commit -m "test: StatusStyle unit tests and CompactFormatter integration"
```

---

### Task 5: Expose `statusStyle` in `SettingsViewModel`

**Files:**
- Modify: `Sources/AutoLogSettings/SettingsViewModel.swift`

**Step 1: Add the stored property** (below `arrowStyle`):

```swift
/// The current status style, kept in sync with ``AutoLogSettingsStorage``.
var statusStyle: LogFormat.StatusStyle = .default
```

**Step 2: Update `currentFormat`**

Change from:
```swift
var currentFormat: LogFormat {
  LogFormat(mainLine: activeElements, arrowStyle: arrowStyle)
}
```
To:
```swift
var currentFormat: LogFormat {
  LogFormat(mainLine: activeElements, arrowStyle: arrowStyle, statusStyle: statusStyle)
}
```

**Step 3: Update `rebuildState(from:)`** — add after `arrowStyle = format.arrowStyle`:

```swift
statusStyle = format.statusStyle
```

**Step 4: Add mutating method** (below `updateArrowStyle`):

```swift
func updateStatusStyle(_ style: LogFormat.StatusStyle) {
  statusStyle = style
  saveToStorage()
}
```

**Step 5: Build**

```bash
swift build --target AutoLogSettings 2>&1 | grep -E "error:|complete"
```
Expected: `Build complete!`

**Step 6: Commit**

```bash
git add Sources/AutoLogSettings/SettingsViewModel.swift
git commit -m "feat: SettingsViewModel exposes statusStyle for UI binding"
```

---

### Task 6: Add Status Style UI to `FormatEditorView`

**Files:**
- Modify: `Sources/AutoLogSettings/FormatEditorView.swift`

**Step 1: Add `statusStyleSection` computed property**

Add immediately after the closing `}` of `arrowStyleSection`:

```swift
private var statusStyleSection: some View {
  VStack(alignment: .leading, spacing: 10) {
    Label("Status", systemImage: "circle.fill")
      .font(.subheadline.weight(.semibold))

    let rows: [(label: String, preview: String,
                get: KeyPath<LogFormat.StatusStyle, String>,
                set: WritableKeyPath<LogFormat.StatusStyle, String>)] = [
      ("Start",   "🔵", \.start,   \.start),
      ("Success", "🟢", \.success, \.success),
      ("Failure", "🔴", \.failure, \.failure),
      ("Warning", "🟡", \.warning, \.warning),
      ("Update",  "🟣", \.update,  \.update),
    ]

    HStack(spacing: 16) {
      ForEach(rows, id: \.label) { row in
        statusField(
          label:   row.label,
          preview: row.preview,
          value: Binding(
            get: { viewModel.statusStyle[keyPath: row.get] },
            set: {
              var s = viewModel.statusStyle
              s[keyPath: row.set] = $0
              viewModel.updateStatusStyle(s)
            }
          )
        )
      }
    }
  }
}

private func statusField(label: String, preview: String, value: Binding<String>) -> some View {
  VStack(alignment: .leading, spacing: 4) {
    HStack(spacing: 4) {
      Text(preview)
        .font(.caption)
      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    TextField("", text: value)
      .textFieldStyle(.roundedBorder)
      .font(.system(.body, design: .monospaced))
      .frame(width: 52)
  }
}
```

**Step 2: Wire it into the `ScrollView`**

In the `ScrollView > VStack` body, add after `arrowStyleSection`:

```swift
statusStyleSection
```

**Step 3: Build**

```bash
swift build --target AutoLogSettings 2>&1 | grep -E "error:|complete"
```
Expected: `Build complete!`

**Step 4: Commit**

```bash
git add Sources/AutoLogSettings/FormatEditorView.swift
git commit -m "feat: status style editor in AutoLogSettings"
```

---

### Task 7: End-to-end verification and push

**Step 1: Full test suite**

```bash
swift test 2>&1 | tail -5
```
Expected: all 146 tests pass.

**Step 2: Build all targets**

```bash
swift build 2>&1 | grep -E "error:|complete"
```

**Step 3: Commit any stray changes**

```bash
git status
# commit anything uncommitted
```

**Step 4: Push**

```bash
git push
```
