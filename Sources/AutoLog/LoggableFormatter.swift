/// A type that formats a ``LoggableEvent`` into a printable string.
public protocol LoggableFormatter: Sendable {
  func format(event: LoggableEvent) -> String
}

/// A compact formatter that renders events in a readable, structured format.
///
/// ### Interaction events (button taps, etc.)
/// ```
/// ->  👆🏼 Run [AsyncExamplesView:42]
/// ```
///
/// ### Function start events (🔵, before body executes)
/// ```
/// --> 🔵 AsyncExamplesViewModel.fetchPreferences(userId: 42) async
/// ```
///
/// ### Function result events (🟢 success, 🔴 failure)
/// ```
/// --> 🟢 AsyncExamplesViewModel.fetchPreferences(userId: 42) async → Prefs(dark, en) ⏱ 38ms
///          ↖ 👆🏼 Run [AsyncExamplesView:42]
///
/// --> 🔴 AsyncExamplesViewModel.fetchUser(id: 99) async
///          ↳ notFound [NetworkError]
///          ↖ 👆🏼 Run [AsyncExamplesView:42]
/// ```
///
/// ### Customising the layout
///
/// Pass a ``LogFormat`` at init time (static override) or configure one globally
/// via `AutoLogSettingsStorage.setLogFormat(_:)` (runtime override). A static
/// override always wins over the global setting.
///
/// ```swift
/// // Static — this formatter always uses this layout, ignoring global settings.
/// let logger = LoggableLogger(
///   formatter: CompactFormatter(format: LogFormat(mainLine: [
///     .depthArrow, .statusEmoji, .functionName, .parameters
///   ]))
/// )
///
/// // Global — all CompactFormatters without a static override pick this up.
/// AutoLogSettingsStorage.setLogFormat(
///   LogFormat(mainLine: [.depthArrow, .statusEmoji, .functionName, .parameters])
/// )
/// ```
public struct CompactFormatter: LoggableFormatter {
  public let profile: DepthProfile

  /// A fixed format override. When `nil`, ``AutoLogSettingsStorage/logFormat()``
  /// is consulted on every call to ``format(event:)``.
  public let format: LogFormat?

  public init(profile: DepthProfile = .mvvm, format: LogFormat? = nil) {
    self.profile = profile
    self.format  = format
  }

  public func format(event: LoggableEvent) -> String {
    let typeName = extractTypeName(from: event.location)
    let fmt      = format ?? AutoLogSettingsStorage.logFormat()
    let depth    = profile.depth(for: typeName) ?? 1
    let arrow    = fmt.arrowStyle.arrow(for: depth)

    // ── Interaction event ────────────────────────────────────────────────────
    // Detected when declaration matches the source's description (set by LoggableSource.run).
    if let source = event.source, event.declaration == source.description {
      let label = source.label ?? source.description
      let line  = extractLine(from: event.location)
      return "\(arrow) \(source.emoji) \(label) [\(typeName):\(line)]"
    }

    let em         = emoji(for: event)
    let funcName   = extractFuncName(from: event.declaration)
    let params     = formatParameters(event.parameters)
    let specifiers = effectSpecifiers(from: event.declaration)

    // ── Build main line from ordered format elements ──────────────────────────
    //
    // Spacing rules:
    //   • Most elements are space-separated.
    //   • "glue" elements attach to the previous token with no leading space:
    //       dotSeparator, parameters, lineNumber.
    //   • functionName glues when it immediately follows dotSeparator.

    struct Segment {
      let text: String
      let noLeadingSpace: Bool
    }

    var segments: [Segment] = []

    for element in fmt.mainLine {
      switch element {

      case .depthArrow:
        segments.append(Segment(text: arrow, noLeadingSpace: false))

      case .statusEmoji:
        segments.append(Segment(text: em, noLeadingSpace: false))

      case .typeName:
        segments.append(Segment(text: typeName, noLeadingSpace: false))

      case .dotSeparator:
        segments.append(Segment(text: ".", noLeadingSpace: true))

      case .functionName:
        // Glue directly to a preceding dot separator; otherwise use a space.
        let glue = segments.last?.text == "."
        segments.append(Segment(text: funcName, noLeadingSpace: glue))

      case .parameters:
        segments.append(Segment(text: "(\(params))", noLeadingSpace: true))

      case .effectSpecifiers:
        let trimmed = specifiers.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { continue }
        segments.append(Segment(text: trimmed, noLeadingSpace: false))

      case .returnValue:
        guard
          case .success(let value) = event.result,
          type(of: value) != Void.self
        else { continue }
        segments.append(Segment(text: "→ \(value)", noLeadingSpace: false))

      case .timing:
        let suffix = timingSuffix(for: event, depth: depth)
          .trimmingCharacters(in: .whitespaces)
        guard !suffix.isEmpty else { continue }
        segments.append(Segment(text: suffix, noLeadingSpace: false))

      case .lineNumber:
        let ln = extractLine(from: event.location)
        segments.append(Segment(text: ":\(ln)", noLeadingSpace: true))

      // ── Spacers — render literal text, always glue to previous token ─────
      case .space:    segments.append(Segment(text: " ",   noLeadingSpace: true))
      case .comma:    segments.append(Segment(text: ",",   noLeadingSpace: true))
      case .pipe:     segments.append(Segment(text: " | ", noLeadingSpace: true))
      case .slash:    segments.append(Segment(text: "/",   noLeadingSpace: true))
      case .newline:  segments.append(Segment(text: "\n",  noLeadingSpace: true))
      }
    }

    var line = ""
    for (i, segment) in segments.enumerated() {
      line += (i == 0 || segment.noLeadingSpace) ? segment.text : " \(segment.text)"
    }

    // ── Second line: error detail OR tags ────────────────────────────────────
    var annotations: [String] = []

    if case .failure(let error) = event.result {
      let errorType = String(describing: type(of: error))
      let desc      = String(describing: error)
      annotations.append("         ↳ \(desc) [\(errorType)]")
    } else if !event.tags.isEmpty {
      let tagList = event.tags.map { "\($0)" }.joined(separator: ", ")
      annotations.append("         ↳ [\(tagList)]")
    }

    // ── Source attribution line ───────────────────────────────────────────────
    // Not shown on start events (they have no source attribution line to keep them lean).
    if !isStartEvent(event), let attribution = sourceAttributionLine(for: event) {
      annotations.append(attribution)
    }

    if !annotations.isEmpty {
      line += "\n" + annotations.joined(separator: "\n")
    }

    return line
  }

  // MARK: - Private helpers

  private func isStartEvent(_ event: LoggableEvent) -> Bool {
    guard let level = event.level as? LogLevel else { return false }
    return level == .start
  }

  private func emoji(for event: LoggableEvent) -> String {
    // LogLevel takes priority — it carries explicit semantic meaning.
    if let logLevel = event.level as? LogLevel {
      return logLevel.emoji
    }

    // Failure always wins for non-LogLevel events.
    if case .failure = event.result { return "🔴" }

    // OSLogType mapping for the @OSLog path.
    if let osLevel = event.level as? OSLogType {
      switch osLevel {
      case .error, .fault: return "🔴"
      case .default:       return "🟡"
      case .info, .debug:  return "🔵"
      default:             return "🟢"
      }
    }

    return "🟢"
  }

  private func timingSuffix(for event: LoggableEvent, depth: Int) -> String {
    // Start events never show timing (they haven't run yet).
    guard !isStartEvent(event) else { return "" }
    guard let duration = event.duration else { return "" }

    let globalOn = AutoLogSettingsStorage.measureTiming()
    let depthOk  = AutoLogSettingsStorage.measureTimingDepths.map { $0.contains(depth) } ?? true
    guard (globalOn && depthOk) || event.isMeasuredExplicitly else { return "" }

    return " ⏱ \(formatDuration(duration))"
  }

  private func formatDuration(_ d: Duration) -> String {
    let totalNs = d.components.seconds * 1_000_000_000
                + d.components.attoseconds / 1_000_000_000
    switch totalNs {
    case ..<1_000:     return "\(totalNs)µs"
    case ..<1_000_000: return "\(totalNs / 1_000)ms"
    default:           return String(format: "%.1fs", Double(totalNs) / 1_000_000_000)
    }
  }

  private func sourceAttributionLine(for event: LoggableEvent) -> String? {
    guard let ctx = event.source as? SourceContext else { return nil }
    let typeName = extractTypeName(from: ctx.location)
    let line     = extractLine(from: ctx.location)
    let label    = ctx.label ?? ctx.description
    return "         ↖ \(ctx.emoji) \(label) [\(typeName):\(line)]"
  }

  private func extractTypeName(from location: String) -> String {
    // Expected format: "Module/TypeName.swift:line:col"
    // Use ".swift" as boundary to handle names like "MyView+Extension.swift" correctly.
    let filename = location.split(separator: "/").last.map(String.init) ?? location
    let stem = filename.components(separatedBy: ".swift").first ?? filename
    return stem.isEmpty ? "Unknown" : stem
  }

  private func extractLine(from location: String) -> String {
    // Format: "Module/TypeName.swift:42:5" — line is the second colon-separated component.
    let parts = location.split(separator: ":", maxSplits: 3, omittingEmptySubsequences: false)
    // parts[0] = "Module/TypeName.swift", parts[1] = "42", parts[2] = "5"
    // Handle Windows-style paths ("C:/foo/Bar.swift:42:5") by taking second-to-last
    // numeric component.
    let candidates = parts.dropFirst().prefix(2)
    return candidates.first(where: { Int($0) != nil }).map(String.init) ?? "?"
  }

  private func extractFuncName(from declaration: String) -> String {
    // "public mutating func deposit(amount: Int)" → "deposit"
    // "func fetch<T: Decodable>(type: T.Type)" → "fetch"
    let afterFunc: String
    if let range = declaration.range(of: "func ") {
      afterFunc = String(declaration[range.upperBound...])
    } else {
      afterFunc = declaration
    }
    let withoutGenerics = afterFunc.split(separator: "<").first.map(String.init) ?? afterFunc
    return withoutGenerics.split(separator: "(").first.map(String.init) ?? withoutGenerics
  }

  private func formatParameters(_ parameters: [String: Any]) -> String {
    guard !parameters.isEmpty else { return "" }
    // [String: Any] has no stable order; sort alphabetically for determinism.
    return parameters
      .sorted { $0.key < $1.key }
      .map { "\($0.key): \($0.value)" }
      .joined(separator: ", ")
  }

  private func effectSpecifiers(from declaration: String) -> String {
    let isAsync = declaration.range(of: #"\basync\b"#, options: .regularExpression) != nil
    return isAsync ? " async" : ""
  }
}
