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
public struct CompactFormatter: LoggableFormatter {
  public let profile: DepthProfile

  public init(profile: DepthProfile = .mvvm) {
    self.profile = profile
  }

  public func format(event: LoggableEvent) -> String {
    let typeName = extractTypeName(from: event.location)
    let arrow    = profile.arrow(for: typeName)
    let depth    = profile.depth(for: typeName) ?? 1

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

    var line = "\(arrow) \(em) \(typeName).\(funcName)(\(params))\(specifiers)"

    // ── Inline return value on success for non-Void results ──────────────────
    if case .success(let value) = event.result, type(of: value) != Void.self {
      line += " → \(value)"
    }

    // ── Inline timing suffix ─────────────────────────────────────────────────
    line += timingSuffix(for: event, depth: depth)

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

    let globalOn = LoggableSettingsStorage.measureTiming()
    let depthOk  = LoggableSettingsStorage.measureTimingDepths.map { $0.contains(depth) } ?? true
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
