/// A type that formats a ``AutoLogEvent`` into a printable string.
public protocol AutoLogFormatter: Sendable {
  func format(event: AutoLogEvent, configuration: AutoLogConfiguration) -> String
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
///          ↳ recent context:
///             • -> 👆🏼 Run [AsyncExamplesView:42]
///             • --> 🔵 AsyncExamplesViewModel.fetchUser(id: 99) async
///          ↳ notFound [NetworkError]
///          ↖ 👆🏼 Run [AsyncExamplesView:42]
/// ```
///
/// ### Customising the layout
///
/// Pass a ``LogFormat`` at init time (static override) or configure one via
/// ``AutoLogConfiguration/logFormat`` (runtime override). A static override
/// always wins over the runtime setting.
///
/// ```swift
/// // Static — this formatter always uses this layout, ignoring global settings.
/// let logger = AutoLogLogger(
///   formatter: CompactFormatter(format: LogFormat(mainLine: [
///     .depthArrow, .statusEmoji, .functionName, .parameters
///   ]))
/// )
///
/// // Global — all CompactFormatters without a static override pick this up.
/// AutoLog.updateConfiguration(
///   AutoLogConfiguration(
///     logFormat: LogFormat(mainLine: [.depthArrow, .statusEmoji, .functionName, .parameters])
///   )
/// )
/// ```
public struct CompactFormatter: AutoLogFormatter {
  public let profile: DepthProfile

  /// A fixed format override. When `nil`, ``AutoLogConfiguration/logFormat`` is
  /// consulted on every call to ``format(event:configuration:)``.
  public let format: LogFormat?

  public init(profile: DepthProfile = .mvvm, format: LogFormat? = nil) {
    self.profile = profile
    self.format  = format
  }

  public func format(
    event: AutoLogEvent,
    configuration: AutoLogConfiguration
  ) -> String {
    let typeName = extractTypeName(from: event.location)
    let fmt      = format ?? configuration.logFormat
    let depth    = profile.depth(for: typeName) ?? 1
    let arrow    = fmt.arrowStyle.arrow(for: depth)

    // ── Interaction event ────────────────────────────────────────────────────
    // Detected when declaration matches the source's description (set by AutoLogSource.run).
    if let source = event.source, event.declaration == source.description {
      let label = source.label ?? source.description
      let trace = (source as? SourceContext).map { " \($0.traceBadge)" } ?? ""
      let line  = extractLine(from: event.location)
      return "\(arrow) \(source.emoji) \(label)\(trace) [\(typeName):\(line)]"
    }

    let em         = emoji(for: event, style: fmt.statusStyle)
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
        let suffix = timingSuffix(
          for: event,
          depth: depth,
          configuration: configuration
        )
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

    if let earlyExit = event.earlyExit {
      annotations.append("         ↳ early exit: \(earlyExit)")
    } else if !event.branchDecisions.isEmpty {
      let branches = event.branchDecisions
        .map(\.description)
        .joined(separator: " -> ")
      annotations.append("         ↳ branch path: \(branches)")
    }

    if case .failure = event.result, !event.errorContext.isEmpty {
      annotations.append("         ↳ recent context:")
      annotations.append(contentsOf: formatErrorContext(event.errorContext))
    }

    if case .failure(let error) = event.result {
      let errorType = String(describing: type(of: error))
      let desc      = String(describing: error)
      annotations.append("         ↳ \(desc) [\(errorType)]")
    } else if !event.visibleTags.isEmpty {
      let tagList = event.visibleTags.map { "\($0)" }.joined(separator: ", ")
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

  private func isStartEvent(_ event: AutoLogEvent) -> Bool {
    guard let level = event.level as? LogLevel else { return false }
    return level == .start
  }

  private func emoji(for event: AutoLogEvent, style: LogFormat.StatusStyle) -> String {
    // LogLevel takes priority — it carries explicit semantic meaning.
    if let logLevel = event.level as? LogLevel {
      switch logLevel {
      case .start:   return style.start
      case .success: return style.success
      case .failure: return style.failure
      case .warning: return style.warning
      case .update:  return style.update
      }
    }
    // Failure always wins for non-LogLevel events.
    if case .failure = event.result { return style.failure }
    // OSLogType mapping for the @OSLog path.
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

  private func timingSuffix(
    for event: AutoLogEvent,
    depth: Int,
    configuration: AutoLogConfiguration
  ) -> String {
    // Start events never show timing (they haven't run yet).
    guard !isStartEvent(event) else { return "" }
    guard let duration = event.duration else { return "" }

    let globalOn = configuration.measureTimingDefault
    let depthOk  = configuration.measureTimingDepths.map { $0.contains(depth) } ?? true
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

  private func sourceAttributionLine(for event: AutoLogEvent) -> String? {
    guard let ctx = event.source as? SourceContext else { return nil }
    let typeName = extractTypeName(from: ctx.location)
    let line     = extractLine(from: ctx.location)
    let label    = ctx.label ?? ctx.description
    return "         ↖ \(ctx.emoji) \(label) \(ctx.traceBadge) [\(typeName):\(line)]"
  }

  private func formatErrorContext(
    _ entries: [AutoLogErrorContextEntry]
  ) -> [String] {
    entries.map { "           • \($0.summary)" }
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
      .map { "\($0.key): \(formatParameterValue($0.value))" }
      .joined(separator: ", ")
  }

  private func effectSpecifiers(from declaration: String) -> String {
    let isAsync = declaration.range(of: #"\basync\b"#, options: .regularExpression) != nil
    return isAsync ? " async" : ""
  }

  private func formatParameterValue(_ value: Any) -> String {
    if isScalarLike(value) {
      return String(describing: value)
    }

    if let type = value as? Any.Type {
      return shortTypeName(from: String(reflecting: type))
    }

    let description = String(describing: value)
    if isTypeOnlyDescription(description, for: value) {
      return shortIdentifierSummary(for: value) ?? shortTypeName(from: description)
    }

    return description
  }

  private func isTypeOnlyDescription(_ description: String, for value: Any) -> Bool {
    let reflectedType = String(reflecting: type(of: value))
    let shortType = shortTypeName(from: reflectedType)
    return description == reflectedType || description == shortType
  }

  private func isScalarLike(_ value: Any) -> Bool {
    switch value {
    case is String,
         is Substring,
         is Character,
         is Bool,
         is Int,
         is Int8,
         is Int16,
         is Int32,
         is Int64,
         is UInt,
         is UInt8,
         is UInt16,
         is UInt32,
         is UInt64,
         is Float,
         is Double,
         is Decimal,
         is UUID:
      return true
    default:
      return false
    }
  }

  private func shortIdentifierSummary(for value: Any) -> String? {
    let mirror = Mirror(reflecting: value)

    guard
      let idChild = mirror.children.first(where: { child in
        isIdentifierLabel(child.label)
      }),
      let shortID = shortIdentifierString(from: idChild.value)
    else {
      return nil
    }

    let label = normalizedIdentifierLabel(idChild.label)
    let typeName = shortTypeName(from: String(reflecting: type(of: value)))
    return "\(typeName).\(label): \(shortID)"
  }

  private func shortIdentifierString(from value: Any, depth: Int = 0) -> String? {
    guard depth < 5 else { return nil }

    let mirror = Mirror(reflecting: value)
    if mirror.displayStyle == .optional {
      guard let child = mirror.children.first else { return nil }
      return shortIdentifierString(from: child.value, depth: depth + 1)
    }

    switch value {
    case let uuid as UUID:
      return "...\(uuid.uuidString.suffix(4).lowercased())"
    case let string as String:
      return abbreviatedIdentifier(string)
    case let substring as Substring:
      return abbreviatedIdentifier(String(substring))
    case let custom as any CustomStringConvertible:
      return abbreviatedIdentifier(custom.description)
    default:
      break
    }

    if let nestedIdentifier = mirror.children.first(where: { child in
      isIdentifierLabel(child.label)
    }) {
      return shortIdentifierString(from: nestedIdentifier.value, depth: depth + 1)
    }

    // Wrapper types often expose the real value as a single unlabeled child.
    if mirror.children.count == 1, let onlyChild = mirror.children.first {
      return shortIdentifierString(from: onlyChild.value, depth: depth + 1)
    }

    return nil
  }

  private func abbreviatedIdentifier(_ raw: String) -> String? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let sanitized = trimmed.replacingOccurrences(of: "-", with: "")
    guard sanitized.count > 4 else { return trimmed }
    return "...\(trimmed.suffix(4))"
  }

  private func shortTypeName(from qualifiedName: String) -> String {
    qualifiedName.split(separator: ".").last.map(String.init) ?? qualifiedName
  }

  private func isIdentifierLabel(_ label: String?) -> Bool {
    let normalized = normalizedIdentifierLabel(label)
    return normalized == "id" || normalized == "identifier" || normalized == "uuid"
  }

  private func normalizedIdentifierLabel(_ label: String?) -> String {
    guard let label else { return "id" }
    return label.trimmingCharacters(in: CharacterSet(charactersIn: "_")).lowercased()
  }
}
