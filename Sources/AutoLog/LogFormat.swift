import Foundation

/// Defines the visual structure of the main log output line.
///
/// `LogFormat` specifies which ``Element`` components appear in the compact,
/// single-line output produced by ``CompactFormatter``, and in what order.
///
/// Secondary lines (error details, tags, source attribution) are always
/// rendered when present, regardless of the format.
///
/// ### Customising the format
/// ```swift
/// // Slim format: emoji + function name only — no type prefix, no timing.
/// AutoLog.updateConfiguration(
///   AutoLogConfiguration(
///     logFormat: LogFormat(
///       mainLine: [.depthArrow, .statusEmoji, .functionName, .parameters, .effectSpecifiers]
///     )
///   )
/// )
/// ```
///
/// ### Restoring the default
/// ```swift
/// AutoLog.updateConfiguration(.default)
/// ```
public struct LogFormat: Sendable, Codable, Equatable {

  /// An ordered list of elements that compose the main log output line.
  public var mainLine: [Element]

  /// A named component that may appear on the main log output line.
  ///
  /// Elements are rendered left-to-right in the order specified by
  /// ``LogFormat/mainLine``. Spacing between elements is managed
  /// automatically: "glue" elements (``dotSeparator``, ``parameters``,
  /// ``lineNumber``, and all spacer cases) attach directly to the preceding
  /// element with no auto-inserted space.
  public enum Element: String, CaseIterable, Sendable, Codable, Equatable, Identifiable {

    // MARK: - Data elements

    /// Depth-proportional arrow prefix derived from the type's architectural layer.
    ///
    /// Examples: `->` (View), `-->` (ViewModel), `--->`
    case depthArrow

    /// Status or level emoji reflecting the event's outcome or explicit level.
    ///
    /// Maps to: 🟢 success · 🔴 failure · 🔵 start / debug · 🟡 default · 🟣 update
    case statusEmoji

    /// The type name extracted from the source-file location.
    ///
    /// Example: `MyViewModel`
    case typeName

    /// The bare function name, without parameters or generic arguments.
    ///
    /// Example: `fetchData`
    case functionName

    /// Inline call parameters as `key: value` pairs in parentheses.
    ///
    /// Example: `(userId: 42, limit: 10)`
    case parameters

    /// Swift effect specifiers declared on the function.
    ///
    /// Currently surfaces `async` when the function is declared `async`.
    case effectSpecifiers

    /// The inline return value on a successful, non-Void result.
    ///
    /// Example: `→ User(id: 1, name: "Alice")`
    case returnValue

    /// The macro-measured execution time.
    ///
    /// Example: `⏱ 38ms`
    case timing

    /// The propagated source emoji plus interaction badge for the current flow.
    ///
    /// Example: `👆🏼-🚀A1B2C3`
    case originBadge

    /// The coarse execution context of the current event.
    ///
    /// Example: `main` or `bg`
    case threadLabel

    /// A compact raw thread identifier.
    ///
    /// Example: `#4AF2`
    case threadID

    /// A compact task identifier derived from the current Swift task.
    ///
    /// Example: `T:8C10`
    case taskID

    /// The source-file line number, glued directly to the preceding element.
    ///
    /// Example: `:42`
    case lineNumber

    // MARK: - Spacer / separator elements
    //
    // Spacers render their literal text with no automatic spacing on either side.
    // They can appear multiple times in a format (e.g. two spaces between elements).

    /// A `.` that glues the preceding and following tokens together.
    ///
    /// Equivalent to placing `typeName` + `dotSeparator` + `functionName` to produce
    /// `MyViewModel.fetchData`.
    case dotSeparator

    /// A single space character ` `.
    case space

    /// A comma `,`.
    case comma

    /// A pipe with surrounding spaces ` | `.
    case pipe

    /// A forward slash `/`.
    case slash

    /// A line break — splits the output onto a new line.
    case newline

    // MARK: - Identifiable

    public var id: String { rawValue }

    // MARK: - Classification

    /// `true` for separator/spacer elements that render literal text and can
    /// appear multiple times in a format.
    public var isSpacer: Bool {
      switch self {
      case .dotSeparator, .space, .comma, .pipe, .slash, .newline: return true
      default: return false
      }
    }

    /// `true` for elements that render as fixed-width metadata columns when
    /// placed at the start of ``LogFormat/mainLine``.
    public var isColumnCandidate: Bool {
      switch self {
      case .originBadge, .timing, .threadLabel, .threadID, .taskID:
        return true
      default:
        return false
      }
    }

    // MARK: - Display metadata

    /// A short human-readable label for use in settings UIs.
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
      case .originBadge:      return "Origin"
      case .threadLabel:      return "Thread"
      case .threadID:         return "Thread ID"
      case .taskID:           return "Task"
      case .lineNumber:       return "Line"
      case .dotSeparator:     return "·"
      case .space:            return "Space"
      case .comma:            return "Comma"
      case .pipe:             return "Pipe"
      case .slash:            return "Slash"
      case .newline:          return "↵"
      }
    }

    /// A brief description of what the element renders.
    public var elementDescription: String {
      switch self {
      case .depthArrow:    return "→, -->, or ---> based on architecture depth"
      case .statusEmoji:   return "🟢 success · 🔴 failure · 🔵 start"
      case .typeName:      return "Class or struct name from the file path"
      case .functionName:  return "Bare function name without generics"
      case .parameters:    return "(key: value, ...) call-site arguments"
      case .effectSpecifiers: return "async keyword when function is async"
      case .returnValue:   return "→ value on successful non-Void return"
      case .timing:        return "12ms duration column or inline ⏱ 12ms timing token"
      case .originBadge:   return "Source emoji plus flow badge, e.g. 👆🏼-🚀A1B2C3"
      case .threadLabel:   return "main or bg execution context"
      case .threadID:      return "Compact raw thread identifier such as #4AF2"
      case .taskID:        return "Compact current Swift task identifier such as T:8C10"
      case .lineNumber:    return ":42 source line, glued to previous token"
      case .dotSeparator:  return "Glues two tokens — no spaces around it"
      case .space:         return "A literal space character"
      case .comma:         return "A literal comma"
      case .pipe:          return "A pipe with spaces: \" | \""
      case .slash:         return "A forward slash /"
      case .newline:       return "Breaks output onto a new line ↵"
      }
    }

    /// Example text fragment rendered by this element (for chip labels in the UI).
    public var previewFragment: String {
      switch self {
      case .depthArrow:    return "-->"
      case .statusEmoji:   return "🟢"
      case .typeName:      return "MyViewModel"
      case .functionName:  return "fetchData"
      case .parameters:    return "(userId: 42)"
      case .effectSpecifiers: return "async"
      case .returnValue:   return "→ User(1)"
      case .timing:        return "12ms"
      case .originBadge:   return "👆🏼-🚀A1B2C3"
      case .threadLabel:   return "main"
      case .threadID:      return "#4AF2"
      case .taskID:        return "T:8C10"
      case .lineNumber:    return ":38"
      case .dotSeparator:  return "·"
      case .space:         return "␣"
      case .comma:         return ","
      case .pipe:          return "|"
      case .slash:         return "/"
      case .newline:       return "↵"
      }
    }
  }

  // MARK: - ArrowStyle

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
      self.start    = start
      self.repeater = repeater
      self.end      = end
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

  // MARK: - Init

  /// Creates a format with the given ordered element list, arrow style, and status style.
  public init(
    mainLine:    [Element],
    arrowStyle:  ArrowStyle  = .default,
    statusStyle: StatusStyle = .default
  ) {
    self.mainLine    = mainLine
    self.arrowStyle  = arrowStyle
    self.statusStyle = statusStyle
  }

  // MARK: - Codable

  private enum CodingKeys: String, CodingKey {
    case mainLine, arrowStyle, statusStyle
  }

  public init(from decoder: Decoder) throws {
    let c        = try decoder.container(keyedBy: CodingKeys.self)
    mainLine     = try c.decode([Element].self,           forKey: .mainLine)
    arrowStyle   = try c.decodeIfPresent(ArrowStyle.self,  forKey: .arrowStyle)  ?? .default
    statusStyle  = try c.decodeIfPresent(StatusStyle.self, forKey: .statusStyle) ?? .default
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(mainLine,    forKey: .mainLine)
    try c.encode(arrowStyle,  forKey: .arrowStyle)
    try c.encode(statusStyle, forKey: .statusStyle)
  }

  /// The legacy pre-column default format.
  static let legacyDefault = LogFormat(mainLine: [
    .depthArrow,
    .statusEmoji,
    .typeName,
    .dotSeparator,
    .functionName,
    .parameters,
    .effectSpecifiers,
    .returnValue,
    .timing,
  ])

  /// The default format for ``CompactFormatter``.
  ///
  /// Produces lines such as:
  /// ```
  /// 👆🏼-🚀A1B2C3 │ 12ms │ main │ --> 🟢 MyViewModel.fetchData(userId: 42) async → User(1)
  /// ```
  public static let `default` = LogFormat(mainLine: [
    .originBadge,
    .timing,
    .threadLabel,
    .depthArrow,
    .statusEmoji,
    .typeName,
    .dotSeparator,
    .functionName,
    .parameters,
    .effectSpecifiers,
    .returnValue,
  ])
}
