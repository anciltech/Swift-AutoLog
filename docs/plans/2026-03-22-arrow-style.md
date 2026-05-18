# Arrow Style Customisation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Let developers define a custom depth arrow via three configurable strings — start, repeater, and end — so `("-", "-", ">")` produces `->` / `-->` / `--->` and `("a", "b", ">")` produces `a>` / `ab>` / `abb>`.

**Architecture:** Add an `ArrowStyle` struct nested inside `LogFormat`. `CompactFormatter` reads `format.arrowStyle` and calls `arrowStyle.arrow(for: depth)` instead of `profile.arrow(for:)`. `SettingsViewModel` exposes the style as a bindable property. A compact three-field row in the companion app's format editor lets the user edit it live, with an inline depth preview.

**Tech Stack:** Swift 6, SwiftUI (macOS 15), `LogFormat` / `CompactFormatter` in `Sources/AutoLog`, companion app in `Sources/AutoLogSettings`.

---

### Task 1: Add `ArrowStyle` to `LogFormat`

**Files:**
- Modify: `Sources/AutoLog/LogFormat.swift`

**Context:** `LogFormat` already has `mainLine: [Element]`. We add a second stored property `arrowStyle: ArrowStyle` with a default so all existing call-sites keep compiling. The `Codable` implementation must handle JSON written by older versions that lack the key — use manual decoding with `decodeIfPresent`.

**Step 1: Add the nested type and property**

Inside `LogFormat`, before `init(mainLine:)`, insert:

```swift
/// Controls how the depth arrow is rendered.
///
/// The arrow at architectural depth *d* is:
/// ```
/// start + String(repeating: repeater, count: d - 1) + end
/// ```
/// So `ArrowStyle(start: "-", repeater: "-", end: ">")` at depths 1–3 gives
/// `->`, `-->`, `--->`.
public struct ArrowStyle: Sendable, Codable, Equatable {
  public var start: String
  public var repeater: String
  public var end: String

  public init(start: String = "-", repeater: String = "-", end: String = ">") {
    self.start = start
    self.repeater = repeater
    self.end = end
  }

  /// The default style, matching the original CompactFormatter output.
  public static let `default` = ArrowStyle()

  /// Returns the arrow string for the given architectural depth (1-based).
  public func arrow(for depth: Int) -> String {
    let reps = max(0, depth - 1)
    return start + String(repeating: repeater, count: reps) + end
  }
}

/// The arrow style used when rendering the ``Element/depthArrow`` component.
public var arrowStyle: ArrowStyle
```

**Step 2: Update `init` to accept arrowStyle with default**

```swift
public init(mainLine: [Element], arrowStyle: ArrowStyle = .default) {
  self.mainLine   = mainLine
  self.arrowStyle = arrowStyle
}
```

**Step 3: Add custom Codable to handle missing key gracefully**

Add these two methods to `LogFormat` (synthesised Codable no longer works once we have
a custom `init(from:)`, so we need both):

```swift
private enum CodingKeys: String, CodingKey {
  case mainLine, arrowStyle
}

public init(from decoder: Decoder) throws {
  let c       = try decoder.container(keyedBy: CodingKeys.self)
  mainLine    = try c.decode([Element].self,      forKey: .mainLine)
  arrowStyle  = try c.decodeIfPresent(ArrowStyle.self, forKey: .arrowStyle) ?? .default
}

public func encode(to encoder: Encoder) throws {
  var c = encoder.container(keyedBy: CodingKeys.self)
  try c.encode(mainLine,   forKey: .mainLine)
  try c.encode(arrowStyle, forKey: .arrowStyle)
}
```

**Step 4: Build to confirm zero errors**

```bash
cd /path/to/swift-autolog
swift build --target AutoLog 2>&1 | grep -E "error:|Build complete"
```
Expected: `Build of target: 'AutoLog' complete!`

**Step 5: Commit**

```bash
git add Sources/AutoLog/LogFormat.swift
git commit -m "feat: add ArrowStyle to LogFormat with graceful Codable fallback"
```

---

### Task 2: Wire `ArrowStyle` into `CompactFormatter`

**Files:**
- Modify: `Sources/AutoLog/LoggableFormatter.swift`

**Context:** `CompactFormatter.format(event:)` currently computes `arrow` via `profile.arrow(for: typeName)`. The `DepthProfile` computes arrows using its own hardcoded `-` / `>` characters. We replace that call with `fmt.arrowStyle.arrow(for: depth)` for both function events and interaction events. `DepthProfile.arrow(for:)` can be removed entirely (it's only called from `CompactFormatter`).

**Step 1: Replace arrow computation in `format(event:)`**

Find the lines:
```swift
let arrow    = profile.arrow(for: typeName)
let depth    = profile.depth(for: typeName) ?? 1
```

Replace with:
```swift
let depth    = profile.depth(for: typeName) ?? 1
let arrow    = fmt.arrowStyle.arrow(for: depth)
```

(Note: `fmt` is already declared on the next line — move the `let fmt` line above these two.)

The updated block should read:
```swift
let typeName = extractTypeName(from: event.location)
let fmt      = format ?? AutoLogSettingsStorage.logFormat()
let depth    = profile.depth(for: typeName) ?? 1
let arrow    = fmt.arrowStyle.arrow(for: depth)
```

**Step 2: Build + run tests**

```bash
swift build --target AutoLog 2>&1 | grep -E "error:|complete"
swift test 2>&1 | tail -5
```
Expected: all 135 tests pass (the snapshot tests embed the default arrow `-->` which matches `ArrowStyle.default`).

**Step 3: Commit**

```bash
git add Sources/AutoLog/LoggableFormatter.swift
git commit -m "feat: CompactFormatter uses ArrowStyle from LogFormat"
```

---

### Task 3: Add tests for `ArrowStyle`

**Files:**
- Modify: `Tests/AutoLogTests/CompactFormatterTests.swift`

**Context:** Add a focused test group that verifies custom arrow styles render correctly and that default decoding round-trips through JSON without losing the style.

**Step 1: Add the tests** (insert after the existing `CompactFormatterTests` suite):

```swift
@Suite
struct ArrowStyleTests {

  @Test func default_producesStandardArrows() {
    let style = LogFormat.ArrowStyle.default
    #expect(style.arrow(for: 1) == "->")
    #expect(style.arrow(for: 2) == "-->")
    #expect(style.arrow(for: 3) == "--->")
  }

  @Test func customStyle_producesExpectedArrows() {
    let style = LogFormat.ArrowStyle(start: "a", repeater: "b", end: ">")
    #expect(style.arrow(for: 1) == "a>")
    #expect(style.arrow(for: 2) == "ab>")
    #expect(style.arrow(for: 4) == "abbb>")
  }

  @Test func emptyRepeater_sameArrowAtAllDepths() {
    let style = LogFormat.ArrowStyle(start: "~", repeater: "", end: ">")
    #expect(style.arrow(for: 1) == "~>")
    #expect(style.arrow(for: 5) == "~>")
  }

  @Test func logFormat_decodesLegacyJsonWithoutArrowStyle() throws {
    // Simulate JSON written by an older version that has no arrowStyle key.
    let json = #"{"mainLine":["depthArrow","statusEmoji"]}"#
    let format = try JSONDecoder().decode(LogFormat.self, from: Data(json.utf8))
    #expect(format.arrowStyle == .default)
  }

  @Test func logFormat_roundTripsArrowStyle() throws {
    let original = LogFormat(
      mainLine: [.depthArrow, .functionName],
      arrowStyle: LogFormat.ArrowStyle(start: "a", repeater: "b", end: ">")
    )
    let data   = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(LogFormat.self, from: data)
    #expect(decoded.arrowStyle == original.arrowStyle)
  }

  @Test func compactFormatter_usesCustomArrow() {
    let format = LogFormat(
      mainLine: [.depthArrow, .statusEmoji, .functionName],
      arrowStyle: LogFormat.ArrowStyle(start: "~", repeater: "~", end: ">")
    )
    let formatter = CompactFormatter(profile: .mvvm, format: format)
    var event = LoggableEvent(
      location: "App/MyViewModel.swift:1:1",
      declaration: "func doWork()"
    )
    event.duration = .milliseconds(0)
    let output = formatter.format(event: event)
    // ViewModel = depth 2 → "~~>"
    #expect(output.hasPrefix("~~>"))
  }
}
```

**Step 2: Run the new tests**

```bash
swift test --filter ArrowStyleTests 2>&1 | tail -10
```
Expected: all 5 pass.

**Step 3: Run the full suite**

```bash
swift test 2>&1 | tail -5
```
Expected: all tests pass (135 + 5 new = 140).

**Step 4: Commit**

```bash
git add Tests/AutoLogTests/CompactFormatterTests.swift
git commit -m "test: ArrowStyle unit tests and CompactFormatter integration"
```

---

### Task 4: Expose `arrowStyle` in `SettingsViewModel`

**Files:**
- Modify: `Sources/AutoLogSettings/SettingsViewModel.swift`

**Context:** `SettingsViewModel` currently only stores `activeElements` and `inactiveElements`. It needs to expose `arrowStyle` so the UI can bind to its three string fields. Saving arrowStyle persists the whole `LogFormat` (which already includes it), so no extra storage call is needed.

**Step 1: Add `arrowStyle` property and update `rebuildState`**

```swift
/// The current arrow style, kept in sync with ``AutoLogSettingsStorage``.
var arrowStyle: LogFormat.ArrowStyle = .default
```

In `rebuildState(from:)`, add:
```swift
arrowStyle = format.arrowStyle
```

**Step 2: Update `currentFormat`**

```swift
var currentFormat: LogFormat {
  LogFormat(mainLine: activeElements, arrowStyle: arrowStyle)
}
```

**Step 3: Add a mutating method**

```swift
func updateArrowStyle(_ style: LogFormat.ArrowStyle) {
  arrowStyle = style
  saveToStorage()
}
```

**Step 4: Build**

```bash
swift build --target AutoLogSettings 2>&1 | grep -E "error:|complete"
```

**Step 5: Commit**

```bash
git add Sources/AutoLogSettings/SettingsViewModel.swift
git commit -m "feat: SettingsViewModel exposes arrowStyle for UI binding"
```

---

### Task 5: Add Arrow Style UI to `FormatEditorView`

**Files:**
- Modify: `Sources/AutoLogSettings/FormatEditorView.swift`

**Context:** Add a third section "Arrow Style" below the palette. It contains three compact labelled text fields (Start · Repeat · End) and a live preview row showing the arrow at depths 1–4.

**Step 1: Add the `arrowStyleSection` view**

Add this below `paletteSection` in the `ScrollView` content, and add a corresponding `private var arrowStyleSection` computed property:

```swift
private var arrowStyleSection: some View {
  VStack(alignment: .leading, spacing: 10) {
    Label("Arrow Style", systemImage: "arrow.right")
      .font(.subheadline.weight(.semibold))

    HStack(spacing: 16) {
      arrowField(label: "Start",  value: Binding(
        get: { viewModel.arrowStyle.start },
        set: { viewModel.updateArrowStyle(
          LogFormat.ArrowStyle(start: $0,
                               repeater: viewModel.arrowStyle.repeater,
                               end:      viewModel.arrowStyle.end))
        }
      ))

      arrowField(label: "Repeat", value: Binding(
        get: { viewModel.arrowStyle.repeater },
        set: { viewModel.updateArrowStyle(
          LogFormat.ArrowStyle(start:    viewModel.arrowStyle.start,
                               repeater: $0,
                               end:      viewModel.arrowStyle.end))
        }
      ))

      arrowField(label: "End",    value: Binding(
        get: { viewModel.arrowStyle.end },
        set: { viewModel.updateArrowStyle(
          LogFormat.ArrowStyle(start:    viewModel.arrowStyle.start,
                               repeater: viewModel.arrowStyle.repeater,
                               end:      $0))
        }
      ))
    }

    // Live depth preview
    HStack(spacing: 12) {
      ForEach(1...4, id: \.self) { depth in
        VStack(spacing: 2) {
          Text(viewModel.arrowStyle.arrow(for: depth))
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(.primary)
          Text("depth \(depth)")
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
      }
      Spacer()
    }
    .padding(10)
    .background(Color.secondary.opacity(0.06))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

private func arrowField(label: String, value: Binding<String>) -> some View {
  VStack(alignment: .leading, spacing: 4) {
    Text(label)
      .font(.caption)
      .foregroundStyle(.secondary)
    TextField("", text: value)
      .textFieldStyle(.roundedBorder)
      .font(.system(.body, design: .monospaced))
      .frame(width: 60)
  }
}
```

**Step 2: Wire it into the `ScrollView`**

In `body`, inside the `ScrollView > VStack`, add after `paletteSection`:

```swift
arrowStyleSection
```

**Step 3: Build**

```bash
swift build --target AutoLogSettings 2>&1 | grep -E "error:|complete"
```

**Step 4: Commit**

```bash
git add Sources/AutoLogSettings/FormatEditorView.swift
git commit -m "feat: arrow style editor with live depth preview in AutoLogSettings"
```

---

### Task 6: Verify everything end-to-end

**Step 1: Full test suite**

```bash
swift test 2>&1 | tail -5
```
Expected: all tests pass.

**Step 2: Build both targets**

```bash
swift build 2>&1 | grep -E "error:|complete"
```

**Step 3: Final commit if any stray changes**

```bash
git status
# commit anything uncommitted
```
