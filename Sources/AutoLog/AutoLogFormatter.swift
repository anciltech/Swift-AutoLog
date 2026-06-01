import Foundation

/// A type that formats a ``AutoLogEvent`` into a printable string.
public protocol AutoLogFormatter: Sendable {
  func format(event: AutoLogEvent, configuration: AutoLogConfiguration) -> String
}

/// A compact formatter that renders events in a readable, structured format.
///
/// ### Interaction events (button taps, etc.)
/// ```
/// 👆🏼-🧵A1B2C3 │      │      │ 👆🏼 Run
/// ```
///
/// ### Function start events (🔵, before body executes)
/// ```
/// 👆🏼-🧵A1B2C3 │      │ main │ ├──🔵 AsyncExamplesViewModel.fetchPreferences(userId: 42) async
/// ```
///
/// ### Function result events (🟢 success, 🔴 failure)
/// ```
/// 👆🏼-🧵A1B2C3 │ 38ms │   bg │ └──🟢 AsyncExamplesViewModel.fetchPreferences(userId: 42) async → Prefs(dark, en)
///
/// 👆🏼-🧵A1B2C3 │ 221ms│   bg │ └──🔴 AsyncExamplesViewModel.fetchUser(id: 99) async → notFound [NetworkError] [1 error handled here]
/// 👆🏼-🧵A1B2C3 │      │      │ ╰─ Recovered in catch block; AsyncExamplesViewModel.fetchUser() continued
/// ˄˄˄˄˄˄˄˄˄˄˄˄ Actions leading up to Error 💥 ˄˄˄˄˄˄˄˄˄˄˄˄
/// 👆🏼-🧵A1B2C3 │  12ms│ main │ └──🟢 AsyncExamplesViewModel.loadUser(id: 99) async
/// 💥 Error in AsyncExamplesViewModel.fetchUser()
/// ˅˅˅˅˅˅˅˅˅˅˅˅˅˅˅˅ End Error Context ˅˅˅˅˅˅˅˅˅˅˅˅˅˅˅˅
/// 👆🏼-🧵A1B2C3 │ 222ms│   bg │ └──🟢 AsyncExamplesViewModel.fetchUser(id: 99) async | 1 error handled internally
/// ```
///
/// ### Customising the layout
///
/// Pass a ``LogFormat`` at init time (static override) or configure one via
/// ``AutoLogConfiguration/logFormat`` (runtime override). A static override
/// always wins over the runtime setting.
public struct CompactFormatter: AutoLogFormatter {
  public let profile: DepthProfile

  /// A fixed format override. When `nil`, ``AutoLogConfiguration/logFormat`` is
  /// consulted on every call to ``format(event:configuration:)``.
  public let format: LogFormat?
  private let fixedFormatPlan: FormatPlan?

  public init(profile: DepthProfile = .mvvm, format: LogFormat? = nil) {
    self.profile         = profile
    self.format          = format
    self.fixedFormatPlan = format.map(FormatPlan.init(format:))
  }

  public func format(
    event: AutoLogEvent,
    configuration: AutoLogConfiguration
  ) -> String {
    let typeName = event.inferredTypeName
    let fmt = format ?? configuration.logFormat
    let plan = fixedFormatPlan ?? (fmt == .default ? .defaultPlan : FormatPlan(format: fmt))
    let depth = event.callSiteDepth ?? profile.depth(for: typeName) ?? 1
    let visibleTags = event.visibleTags
    var parameterText = ParameterText(
      parameters: event.parameters,
      labels: event.parameterLabels
    )

    let mainBody: String
    if let source = event.source, event.declaration == source.description {
      mainBody = interactionBody(for: event, includesLineNumber: plan.includesLineNumber)
    } else if event.source is SourceContext {
      mainBody = traceBody(
        for: event,
        typeName: typeName,
        depth: depth,
        inlineElements: plan.inlineElements,
        fmt: fmt,
        configuration: configuration,
        parameterText: &parameterText
      )
    } else {
      mainBody = standardBody(
        for: event,
        typeName: typeName,
        depth: depth,
        inlineElements: plan.inlineElements,
        fmt: fmt,
        configuration: configuration,
        parameterText: &parameterText
      )
    }

    var lines = [renderMainRow(
      body: mainBody,
      event: event,
      depth: depth,
      columnElements: plan.columnElements,
      configuration: configuration
    )]

    if let detail = detailAnnotation(for: event) {
      lines.append(
        renderRow(
          body: "╰─ \(detail)",
          event: event,
          depth: depth,
          columnElements: plan.columnElements,
          configuration: configuration,
          rowKind: .annotation
        )
      )
    }

    if case .failure = event.result, !event.errorContext.isEmpty {
      lines.append(sectionDivider("Actions leading up to Error 💥", fill: "˄"))
      lines.append(contentsOf: event.errorContext.map(\.summary))
      lines.append("💥 Error in \(event.inferredTypeName).\(event.functionName)()")
      lines.append(sectionDivider("End Error Context", fill: "˅"))
    }

    if case .failure(let error) = event.result,
       !plan.includesReturnValue {
      lines.append(
        renderRow(
          body: "╰─ \(formattedError(error))",
          event: event,
          depth: depth,
          columnElements: plan.columnElements,
          configuration: configuration,
          rowKind: .annotation
        )
      )
    } else if !visibleTags.isEmpty {
      let tagList = formatVisibleTags(visibleTags)
      lines.append(
        renderRow(
          body: "╰─ [\(tagList)]",
          event: event,
          depth: depth,
          columnElements: plan.columnElements,
          configuration: configuration,
          rowKind: .annotation
        )
      )
    }

    return lines.joined(separator: "\n")
  }

  // MARK: - Row Rendering

  private enum RowKind {
    case main
    case annotation
  }

  private enum Alignment {
    case leading
    case trailing
  }

  private struct ParameterText {
    let parameters: [String: Any]
    let labels: [String]
    private var formatted: String?

    init(parameters: [String: Any], labels: [String]) {
      self.parameters = parameters
      self.labels = labels
    }

    mutating func render(using formatter: ([String: Any], [String]) -> String) -> String {
      if let formatted {
        return formatted
      }

      let value = formatter(parameters, labels)
      formatted = value
      return value
    }
  }

  private struct FormatPlan: Sendable {
    static let defaultPlan = FormatPlan(format: .default)

    let columnElements: [LogFormat.Element]
    let inlineElements: [LogFormat.Element]
    let includesReturnValue: Bool
    let includesLineNumber: Bool

    init(format: LogFormat) {
      var columnElements: [LogFormat.Element] = []
      var inlineElements: [LogFormat.Element] = []
      var scanningColumns = true
      var includesReturnValue = false
      var includesLineNumber = false

      columnElements.reserveCapacity(format.mainLine.count)
      inlineElements.reserveCapacity(format.mainLine.count)

      for element in format.mainLine {
        if scanningColumns, element.isColumnCandidate {
          columnElements.append(element)
          continue
        }

        scanningColumns = false
        inlineElements.append(element)

        switch element {
        case .returnValue:
          includesReturnValue = true
        case .lineNumber:
          includesLineNumber = true
        default:
          break
        }
      }

      self.columnElements = columnElements
      self.inlineElements = inlineElements
      self.includesReturnValue = includesReturnValue
      self.includesLineNumber = includesLineNumber
    }
  }

  private func renderRow(
    body: String,
    event: AutoLogEvent,
    depth: Int,
    columnElements: [LogFormat.Element],
    configuration: AutoLogConfiguration,
    rowKind: RowKind
  ) -> String {
    guard !columnElements.isEmpty else { return body }

    var hasContent = false
    var columns: [String] = []
    columns.reserveCapacity(columnElements.count)

    for element in columnElements {
      let value = columnText(
        for: element,
        event: event,
        depth: depth,
        configuration: configuration,
        rowKind: rowKind
      )
      hasContent = hasContent || !value.isEmpty
      columns.append(
        padded(
          value,
          width: columnWidth(for: element),
          alignment: columnAlignment(for: element)
        )
      )
    }

    guard hasContent else { return body }
    return columns.joined(separator: " │ ") + " │ " + body
  }

  private func renderMainRow(
    body: String,
    event: AutoLogEvent,
    depth: Int,
    columnElements: [LogFormat.Element],
    configuration: AutoLogConfiguration
  ) -> String {
    if isInteractionEvent(event) {
      let badge = originBadge(for: event)
      if badge.isEmpty {
        return body
      }
      return "\(badge) - \(body)"
    }

    return renderRow(
      body: body,
      event: event,
      depth: depth,
      columnElements: columnElements,
      configuration: configuration,
      rowKind: .main
    )
  }

  private func columnText(
    for element: LogFormat.Element,
    event: AutoLogEvent,
    depth: Int,
    configuration: AutoLogConfiguration,
    rowKind: RowKind
  ) -> String {
    switch element {
    case .originBadge:
      return originBadge(for: event)
    case .timing:
      guard rowKind == .main else { return "" }
      return timingText(
        for: event,
        depth: depth,
        configuration: configuration,
        inline: false
      )
    case .threadLabel:
      guard rowKind == .main, !isInteractionEvent(event) else { return "" }
      return event.executionContext.threadLabel
    case .threadID:
      guard rowKind == .main, !isInteractionEvent(event) else { return "" }
      return event.executionContext.abbreviatedThreadID ?? ""
    case .taskID:
      guard rowKind == .main, !isInteractionEvent(event) else { return "" }
      return event.executionContext.taskID ?? ""
    default:
      return ""
    }
  }

  private func columnWidth(for element: LogFormat.Element) -> Int {
    switch element {
    case .originBadge: return 9
    case .timing: return 7
    case .threadLabel: return 4
    case .threadID: return 6
    case .taskID: return 8
    default: return 0
    }
  }

  private func columnAlignment(for element: LogFormat.Element) -> Alignment {
    switch element {
    case .timing:
      return .trailing
    default:
      return .leading
    }
  }

  private func padded(_ text: String, width: Int, alignment: Alignment) -> String {
    guard width > 0 else { return text }
    let padding = max(0, width - emojiAwareWidth(text))
    switch alignment {
    case .leading:
      return text + String(repeating: " ", count: padding)
    case .trailing:
      return String(repeating: " ", count: padding) + text
    }
  }

  private func emojiAwareWidth(_ text: String) -> Int {
    text.reduce(into: 0) { width, char in
      let scalars = char.unicodeScalars
      guard let first = scalars.first else { return }
      let isWide = first.properties.isEmojiPresentation ||
        (first.properties.isEmoji && scalars.contains { $0.value == 0xFE0F })
      width += isWide ? 2 : 1
    }
  }

  // MARK: - Body Rendering

  private func interactionBody(
    for event: AutoLogEvent,
    includesLineNumber: Bool
  ) -> String {
    guard let source = event.source else { return event.declaration }
    var body = "\(source.emoji) \(source.label ?? source.description)"
    body += " [\(event.shortLocation)]"
    if includesLineNumber {
      body += ":\(event.sourceLine)"
    }
    return body
  }

  private func traceBody(
    for event: AutoLogEvent,
    typeName: String,
    depth: Int,
    inlineElements: [LogFormat.Element],
    fmt: LogFormat,
    configuration: AutoLogConfiguration,
    parameterText: inout ParameterText
  ) -> String {
    let prefix = tracePrefix(for: event, depth: depth)
    if fmt == .default {
      return defaultBodyText(
        for: event,
        typeName: typeName,
        depth: depth,
        configuration: configuration,
        forcedPrefix: prefix,
        parameterText: &parameterText
      )
    }
    return bodyText(
      for: event,
      typeName: typeName,
      depth: depth,
      inlineElements: inlineElements,
      fmt: fmt,
      configuration: configuration,
      forcedPrefix: prefix,
      parameterText: &parameterText
    )
  }

  private func standardBody(
    for event: AutoLogEvent,
    typeName: String,
    depth: Int,
    inlineElements: [LogFormat.Element],
    fmt: LogFormat,
    configuration: AutoLogConfiguration,
    parameterText: inout ParameterText
  ) -> String {
    if fmt == .default {
      return defaultBodyText(
        for: event,
        typeName: typeName,
        depth: depth,
        configuration: configuration,
        forcedPrefix: nil,
        parameterText: &parameterText
      )
    }
    return bodyText(
      for: event,
      typeName: typeName,
      depth: depth,
      inlineElements: inlineElements,
      fmt: fmt,
      configuration: configuration,
      forcedPrefix: nil,
      parameterText: &parameterText
    )
  }

  private func defaultBodyText(
    for event: AutoLogEvent,
    typeName: String,
    depth: Int,
    configuration: AutoLogConfiguration,
    forcedPrefix: String?,
    parameterText: inout ParameterText
  ) -> String {
    var line = forcedPrefix ?? LogFormat.ArrowStyle.default.arrow(for: depth)
    let status = emoji(for: event, style: .default)

    if forcedPrefix == nil {
      line += " "
    }
    line += status
    line += " "
    line += typeName
    line += "."
    line += event.functionName
    line += "("
    line += parameterText.render(using: formatParameters)
    line += ")"

    if event.hasAsyncEffect {
      line += " async"
    }

    if case .success(let value) = event.result, type(of: value) != Void.self {
      line += " → \(value)"
    } else if case .failure(let error) = event.result {
      line += " → \(formattedError(error))"
    }

    if let handledErrorBadge = handledErrorBadge(for: event) {
      line += " \(handledErrorBadge)"
    }

    if let handledErrorSummary = handledErrorSummary(for: event) {
      line += " | \(handledErrorSummary)"
    }

    return line
  }

  private func bodyText(
    for event: AutoLogEvent,
    typeName: String,
    depth: Int,
    inlineElements: [LogFormat.Element],
    fmt: LogFormat,
    configuration: AutoLogConfiguration,
    forcedPrefix: String?,
    parameterText: inout ParameterText
  ) -> String {
    let arrow = fmt.arrowStyle.arrow(for: depth)
    let em = emoji(for: event, style: fmt.statusStyle)
    let funcName = event.functionName
    let hasAsyncSpecifier = event.hasAsyncEffect
    var line = ""
    var isFirstSegment = true
    var previousElement: LogFormat.Element?
    var previousWasForcedPrefix = false

    func appendSegment(_ text: String, noLeadingSpace: Bool, element: LogFormat.Element? = nil) {
      guard !text.isEmpty else { return }
      if !isFirstSegment && !noLeadingSpace {
        line.append(" ")
      }
      line.append(contentsOf: text)
      isFirstSegment = false
      previousElement = element
      previousWasForcedPrefix = element == .depthArrow && forcedPrefix != nil
    }

    for element in inlineElements {
      switch element {
      case .depthArrow:
        let prefix = forcedPrefix ?? arrow
        appendSegment(prefix, noLeadingSpace: false, element: .depthArrow)
      case .statusEmoji:
        appendSegment(
          em,
          noLeadingSpace: previousWasForcedPrefix,
          element: .statusEmoji
        )
      case .typeName:
        appendSegment(typeName, noLeadingSpace: false, element: .typeName)
      case .dotSeparator:
        appendSegment(".", noLeadingSpace: true, element: .dotSeparator)
      case .functionName:
        appendSegment(
          funcName,
          noLeadingSpace: previousElement == .dotSeparator,
          element: .functionName
        )
      case .parameters:
        let params = parameterText.render(using: formatParameters)
        appendSegment("(\(params))", noLeadingSpace: true, element: .parameters)
      case .effectSpecifiers:
        guard hasAsyncSpecifier else { continue }
        appendSegment("async", noLeadingSpace: false, element: .effectSpecifiers)
      case .returnValue:
        if case .success(let value) = event.result, type(of: value) != Void.self {
          appendSegment("→ \(value)", noLeadingSpace: false, element: .returnValue)
        } else if case .failure(let error) = event.result {
          appendSegment(
            "→ \(formattedError(error))",
            noLeadingSpace: false,
            element: .returnValue
          )
        }
      case .timing:
        let timing = timingText(
          for: event,
          depth: depth,
          configuration: configuration,
          inline: true
        )
        guard !timing.isEmpty else { continue }
        appendSegment(timing, noLeadingSpace: false, element: .timing)
      case .originBadge:
        let badge = originBadge(for: event)
        guard !badge.isEmpty else { continue }
        appendSegment(badge, noLeadingSpace: false, element: .originBadge)
      case .threadLabel:
        appendSegment(
          event.executionContext.threadLabel,
          noLeadingSpace: false,
          element: .threadLabel
        )
      case .threadID:
        guard let threadID = event.executionContext.abbreviatedThreadID else { continue }
        appendSegment(threadID, noLeadingSpace: false, element: .threadID)
      case .taskID:
        guard let taskID = event.executionContext.taskID else { continue }
        appendSegment(taskID, noLeadingSpace: false, element: .taskID)
      case .lineNumber:
        appendSegment(
          ":\(event.sourceLine)",
          noLeadingSpace: true,
          element: .lineNumber
        )
      case .space:
        appendSegment(" ", noLeadingSpace: true, element: .space)
      case .comma:
        appendSegment(",", noLeadingSpace: true, element: .comma)
      case .pipe:
        appendSegment(" | ", noLeadingSpace: true, element: .pipe)
      case .slash:
        appendSegment("/", noLeadingSpace: true, element: .slash)
      case .newline:
        appendSegment("\n", noLeadingSpace: true, element: .newline)
      }
    }

    if let handledErrorBadge = handledErrorBadge(for: event) {
      appendSegment(handledErrorBadge, noLeadingSpace: false)
    }

    if let handledErrorSummary = handledErrorSummary(for: event) {
      appendSegment("| \(handledErrorSummary)", noLeadingSpace: false)
    }

    return line
  }

  // MARK: - Details

  private func detailAnnotation(for event: AutoLogEvent) -> String? {
    if let handledError = event.handledError {
      return handledErrorAnnotation(for: event, handledError: handledError)
    }

    var details: [String] = []

    if let earlyExit = event.earlyExit {
      details.append(formatEarlyExitAnnotation(earlyExit))
    } else if !event.branchDecisions.isEmpty {
      var branches = ""
      var hasBranch = false

      for decision in event.branchDecisions where
        decision.kind == .if || decision.kind == .elseif || decision.kind == .guard
      {
        if hasBranch {
          branches += " -> "
        }
        branches += formatBranchDecision(decision)
        hasBranch = true
      }

      if hasBranch {
        details.append("branch path: \(branches)")
      }
    }

    guard !details.isEmpty else { return nil }
    return details.joined(separator: " • ")
  }

  private func formattedError(_ error: any Error) -> String {
    let errorType = String(describing: type(of: error))
    let description = String(describing: error)
    return "\(description) [\(errorType)]"
  }

  private func handledErrorAnnotation(
    for event: AutoLogEvent,
    handledError: AutoLogHandledError
  ) -> String {
    if handledError.message != AutoLogHandledError.defaultMessage {
      return handledError.message
    }

    return "Recovered in catch block; \(event.inferredTypeName).\(event.functionName)() continued"
  }

  private func handledErrorBadge(for event: AutoLogEvent) -> String? {
    guard event.handledError != nil, event.handledErrorCount > 0 else { return nil }
    let label = event.handledErrorCount == 1 ? "error" : "errors"
    return "[\(event.handledErrorCount) \(label) handled here]"
  }

  private func handledErrorSummary(for event: AutoLogEvent) -> String? {
    guard event.handledError == nil, event.handledErrorCount > 0 else { return nil }
    let label = event.handledErrorCount == 1 ? "error" : "errors"
    return "\(event.handledErrorCount) \(label) handled internally"
  }

  private func sectionDivider(_ title: String, fill: Character) -> String {
    let totalWidth = 58
    let content = " \(title) "
    let sideWidth = max(8, (totalWidth - content.count) / 2)
    let left = String(repeating: String(fill), count: sideWidth)
    let rightCount = max(8, totalWidth - content.count - sideWidth)
    let right = String(repeating: String(fill), count: rightCount)
    return left + content + right
  }

  private func originBadge(for event: AutoLogEvent) -> String {
    if let source = event.source as? SourceContext {
      let shortBadge = source.interactionID.prefix(3)
      return "\(source.emoji)-\(source.flowMarker)\(shortBadge)"
    }

    return ""
  }

  // MARK: - Existing Formatting Helpers

  private func isInteractionEvent(_ event: AutoLogEvent) -> Bool {
    guard let source = event.source else { return false }
    return event.declaration == source.description
  }

  private func isStartEvent(_ event: AutoLogEvent) -> Bool {
    guard let level = event.level as? LogLevel else { return false }
    return level == .start
  }

  private func emoji(for event: AutoLogEvent, style: LogFormat.StatusStyle) -> String {
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

  private func timingText(
    for event: AutoLogEvent,
    depth: Int,
    configuration: AutoLogConfiguration,
    inline: Bool
  ) -> String {
    guard !isStartEvent(event) else { return "" }
    guard let duration = event.duration else { return "" }

    let globalOn = configuration.measureTimingDefault
    let depthOk = configuration.measureTimingDepths.map { $0.contains(depth) } ?? true
    guard (globalOn && depthOk) || event.isMeasuredExplicitly else { return "" }

    let formatted = formatDuration(duration, configuration: configuration)
    return inline ? "⏱ \(formatted)" : formatted
  }

  private func tracePrefix(for event: AutoLogEvent, depth: Int) -> String {
    let corner = isTerminalTraceEvent(event) ? "└" : "├"
    return corner + String(repeating: "─", count: max(depth, 2))
  }

  private func isTerminalTraceEvent(_ event: AutoLogEvent) -> Bool {
    !isStartEvent(event)
  }

  private func formatDuration(
    _ d: Duration,
    configuration: AutoLogConfiguration
  ) -> String {
    let seconds = durationInSeconds(d)
    if configuration.normalizedTiming {
      if seconds >= 10 {
        return String(format: "%.1fs", seconds)
      }
      return String(format: "%.3fs", seconds)
    }

    let totalNs = durationInNanoseconds(d)
    switch totalNs {
    case ..<1_000:
      return "\(totalNs)ns"
    case ..<1_000_000:
      return formatDurationComponent(Double(totalNs) / 1_000, unit: "µs")
    case ..<1_000_000_000:
      return formatDurationComponent(Double(totalNs) / 1_000_000, unit: "ms")
    default:
      return formatDurationComponent(seconds, unit: "s")
    }
  }

  private func durationInNanoseconds(_ d: Duration) -> Int64 {
    let totalNs = d.components.seconds * 1_000_000_000
      + d.components.attoseconds / 1_000_000_000
    return totalNs
  }

  private func durationInSeconds(_ d: Duration) -> Double {
    Double(durationInNanoseconds(d)) / 1_000_000_000
  }

  private func formatDurationComponent(_ value: Double, unit: String) -> String {
    let rounded = value.rounded()
    if abs(value - rounded) < 0.05 {
      return "\(Int(rounded))\(unit)"
    }

    return String(format: "%.1f%@", value, unit)
  }

  private func formatEarlyExitAnnotation(_ earlyExit: AutoLogEarlyExit) -> String {
    var line = "↘️"

    if let condition = earlyExit.condition?.trimmingCharacters(in: .whitespacesAndNewlines),
       !condition.isEmpty {
      line += " \(condition)"
    }

    if earlyExit.intent != .unknown {
      line += " • \(earlyExit.intent.rawValue)"
    }

    if let message = earlyExit.message?.trimmingCharacters(in: .whitespacesAndNewlines),
       !message.isEmpty {
      line += " • \(message)"
    }

    return line
  }

  private func formatBranchDecision(_ decision: AutoLogBranchDecision) -> String {
    let kind: String
    switch decision.kind {
    case .guard:
      kind = "guard"
    case .if:
      kind = "if"
    case .elseif:
      kind = "else if"
    case .else:
      kind = "else"
    case .switchCase:
      kind = "switch case"
    case .switchDefault:
      kind = "switch default"
    }

    guard let condition = decision.condition?.trimmingCharacters(in: .whitespacesAndNewlines),
          !condition.isEmpty else {
      return kind
    }

    return "\(kind) \(compactBranchCondition(condition))"
  }

  private func compactBranchCondition(_ condition: String) -> String {
    let trimmed = condition.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.hasPrefix("let ") {
      return String(trimmed.dropFirst(4))
    }
    return trimmed
  }

  private func formatParameters(_ parameters: [String: Any], labels: [String]) -> String {
    switch parameters.count {
    case 0:
      return ""
    case 1:
      guard let (label, value) = parameters.first else { return "" }
      return "\(label): \(formatParameterValue(value))"
    default:
      var result = ""

      for (index, key) in labels.enumerated() {
        if index > 0 {
          result += ", "
        }
        guard let value = parameters[key] else { continue }
        result += "\(key): \(formatParameterValue(value))"
      }

      return result
    }
  }

  private func formatVisibleTags(_ tags: [any Taggable]) -> String {
    guard let firstTag = tags.first else { return "" }

    var formatted = String(describing: firstTag)
    for tag in tags.dropFirst() {
      formatted += ", "
      formatted += String(describing: tag)
    }

    return formatted
  }

  private func formatParameterValue(_ value: Any) -> String {
    if isScalarLike(value) {
      return String(describing: value)
    }

    if let type = value as? Any.Type {
      return shortTypeName(from: String(reflecting: type))
    }

    if let custom = value as? any CustomStringConvertible {
      let description = custom.description
      if isClearlyValueDescription(description) {
        return description
      }
    }

    let description = String(describing: value)
    if isTypeOnlyDescription(description, for: value) {
      return shortIdentifierSummary(for: value) ?? shortTypeName(from: description)
    }

    return description
  }

  private func isClearlyValueDescription(_ description: String) -> Bool {
    guard let first = description.first else { return false }
    if first.isLowercase || first.isNumber {
      return true
    }

    return description.contains { character in
      character.isWhitespace || ":,()[]{}=/\\\"'".contains(character)
    }
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

    let label = normalizedIdentifierLabel(idChild.label) ?? "id"
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

    if mirror.children.count == 1, let child = mirror.children.first {
      return shortIdentifierString(from: child.value, depth: depth + 1)
    }

    return nil
  }

  private func abbreviatedIdentifier(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let alphanumerics = trimmed.filter { $0.isLetter || $0.isNumber }
    guard alphanumerics.count >= 4 else { return trimmed }
    return "...\(alphanumerics.suffix(4).lowercased())"
  }

  private func isIdentifierLabel(_ label: String?) -> Bool {
    guard let normalized = normalizedIdentifierLabel(label) else { return false }
    return normalized == "id" || normalized == "identifier"
  }

  private func normalizedIdentifierLabel(_ label: String?) -> String? {
    guard let label else { return nil }
    return label.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
  }

  private func shortTypeName(from reflectedType: String) -> String {
    reflectedType.split(separator: ".").last.map(String.init) ?? reflectedType
  }
}
