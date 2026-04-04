import AutoLog
import Foundation
import Observation

/// Manages the two-zone format editor state and synchronises with
/// ``AutoLogConfigurationStore``.
@MainActor
@Observable
final class SettingsViewModel {
  let configurationStore: AutoLogConfigurationStore

  // MARK: - State

  /// Ordered active elements — defines the live ``LogFormat``.
  var activeElements: [LogFormat.Element] = []

  /// Elements available in the palette (not currently active).
  ///
  /// Data elements appear here when not in the active strip.
  /// Spacer elements are always present — they are infinitely reusable.
  var inactiveElements: [LogFormat.Element] = []

  /// The current arrow style, kept in sync with the persisted configuration.
  var arrowStyle: LogFormat.ArrowStyle = .default

  /// The current status style, kept in sync with the persisted configuration.
  var statusStyle: LogFormat.StatusStyle = .default

  /// The full persisted runtime configuration. The editor currently adjusts the
  /// log format only, but it preserves the rest of the snapshot.
  private(set) var configuration: AutoLogConfiguration = .default

  // MARK: - Init

  init(configurationStore: AutoLogConfigurationStore = .shared) {
    self.configurationStore = configurationStore
    loadFromStorage()
  }

  // MARK: - Derived

  /// The format produced by the current active element ordering.
  var currentFormat: LogFormat {
    LogFormat(mainLine: activeElements, arrowStyle: arrowStyle, statusStyle: statusStyle)
  }

  // MARK: - Persistence

  func loadFromStorage() {
    configuration = configurationStore.loadConfiguration() ?? .default
    rebuildState(from: configuration.logFormat)
  }

  func saveToStorage() {
    configuration.logFormat = currentFormat
    configurationStore.saveConfiguration(configuration)
  }

  func resetToDefault() {
    rebuildState(from: .default)
    saveToStorage()
  }

  // MARK: - Mutations

  /// Move an element from the palette into the active strip at `index`.
  func activate(_ element: LogFormat.Element, at index: Int) {
    let clamped = min(index, activeElements.count)
    activeElements.insert(element, at: clamped)
    if !element.isSpacer {
      inactiveElements.removeAll { $0 == element }
    }
    saveToStorage()
  }

  /// Remove the active chip at `index`, returning it to the palette.
  func deactivate(at index: Int) {
    guard activeElements.indices.contains(index) else { return }
    let element = activeElements.remove(at: index)
    if !element.isSpacer, !inactiveElements.contains(element) {
      inactiveElements.append(element)
      sortInactive()
    }
    saveToStorage()
  }

  /// Reorder within the active strip: move chip at `fromIndex` so it sits before
  /// whichever chip was originally at `toIndex`.
  func moveInActive(from fromIndex: Int, to toIndex: Int) {
    guard fromIndex != toIndex,
          activeElements.indices.contains(fromIndex) else { return }
    let element = activeElements.remove(at: fromIndex)
    // After removal the array shrinks, so adjust destination if needed.
    let dest = min(fromIndex < toIndex ? toIndex - 1 : toIndex, activeElements.count)
    activeElements.insert(element, at: dest)
    saveToStorage()
  }

  func updateArrowStyle(_ style: LogFormat.ArrowStyle) {
    arrowStyle = style
    saveToStorage()
  }

  func updateStatusStyle(_ style: LogFormat.StatusStyle) {
    statusStyle = style
    saveToStorage()
  }

  // MARK: - Code snippet

  var codeSnippet: String {
    let list = currentFormat.mainLine
      .map { "            .\($0.rawValue)" }
      .joined(separator: ",\n")
    return """
    AutoLog.bootstrap(
      configuration: AutoLogConfiguration(
        emitStartEvents: \(configuration.emitStartEvents),
        measureTimingDefault: \(configuration.measureTimingDefault),
        measureTimingDepths: \(renderDepths(configuration.measureTimingDepths)),
        logFormat: LogFormat(mainLine: [
    """ + "\n" + list + "\n" + """
        ], arrowStyle: \(renderArrowStyle(arrowStyle)), statusStyle: \(renderStatusStyle(statusStyle))
      )
    )
    """
  }

  // MARK: - Private helpers

  private func rebuildState(from format: LogFormat) {
    activeElements = format.mainLine
    arrowStyle     = format.arrowStyle
    statusStyle    = format.statusStyle

    // Data elements in the palette = all non-spacer elements not used in active strip.
    let activeDataSet = Set(format.mainLine.filter { !$0.isSpacer })
    let dataInPalette = LogFormat.Element.allCases.filter {
      !$0.isSpacer && !activeDataSet.contains($0)
    }
    // Spacers always appear in the palette.
    let spacersInPalette = LogFormat.Element.allCases.filter { $0.isSpacer }

    inactiveElements = dataInPalette + spacersInPalette
  }

  private func sortInactive() {
    // Keep the allCases order so the palette is stable.
    let order = LogFormat.Element.allCases
    inactiveElements.sort { order.firstIndex(of: $0)! < order.firstIndex(of: $1)! }
  }

  private func renderDepths(_ depths: Set<Int>?) -> String {
    guard let depths else { return "nil" }
    return "[" + depths.sorted().map(\.description).joined(separator: ", ") + "]"
  }

  private func renderArrowStyle(_ style: LogFormat.ArrowStyle) -> String {
    "LogFormat.ArrowStyle(start: \(literal(style.start)), repeater: \(literal(style.repeater)), end: \(literal(style.end)))"
  }

  private func renderStatusStyle(_ style: LogFormat.StatusStyle) -> String {
    """
    LogFormat.StatusStyle(
      start: \(literal(style.start)),
      success: \(literal(style.success)),
      failure: \(literal(style.failure)),
      warning: \(literal(style.warning)),
      update: \(literal(style.update))
    )
    """
      .replacingOccurrences(of: "\n", with: " ")
  }

  private func literal(_ value: String) -> String {
    "\"" + value
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"") + "\""
  }
}
