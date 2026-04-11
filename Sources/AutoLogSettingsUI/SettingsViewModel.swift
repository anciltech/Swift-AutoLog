import AutoLog
import Foundation
import Observation

/// Manages output profiles for the companion settings app and synchronises with
/// ``AutoLogConfigurationStore``.
@MainActor
@Observable
final class SettingsViewModel {
  let configurationStore: AutoLogConfigurationStore

  // MARK: - State

  var selectedOutputID: String = ""
  var activeElements: [LogFormat.Element] = []
  var inactiveElements: [LogFormat.Element] = []
  var arrowStyle: LogFormat.ArrowStyle = .default
  var statusStyle: LogFormat.StatusStyle = .default
  private(set) var configuration: AutoLogConfiguration = .default

  init(configurationStore: AutoLogConfigurationStore = .shared) {
    self.configurationStore = configurationStore
    loadFromStorage()
  }

  // MARK: - Derived

  var outputs: [AutoLogOutput] {
    configuration.outputs
  }

  var selectedOutputIndex: Int? {
    configuration.outputs.firstIndex { $0.id == selectedOutputID }
  }

  var selectedOutput: AutoLogOutput? {
    guard let selectedOutputIndex else { return nil }
    return configuration.outputs[selectedOutputIndex]
  }

  var currentFormat: LogFormat {
    LogFormat(mainLine: activeElements, arrowStyle: arrowStyle, statusStyle: statusStyle)
  }

  var selectedOutputRouteText: String {
    selectedOutput?.route.rawValue ?? ""
  }

  var selectedTypeFilterText: String {
    selectedOutput?.typeNameFilters.joined(separator: ", ") ?? ""
  }

  // MARK: - Persistence

  func loadFromStorage() {
    configuration = configurationStore.loadConfiguration() ?? .default
    if configuration.outputs.isEmpty {
      configuration.outputs = configuration.effectiveOutputs
    }
    configuration = synchronizeLegacyFields(in: configuration)
    ensureSelection()
    rebuildStateFromSelectedOutput()
  }

  func saveToStorage() {
    configuration = synchronizeLegacyFields(in: configuration)
    configurationStore.saveConfiguration(configuration)
  }

  func resetToDefault() {
    configuration = .default
    configuration.outputs = configuration.effectiveOutputs
    configuration = synchronizeLegacyFields(in: configuration)
    ensureSelection()
    rebuildStateFromSelectedOutput()
    saveToStorage()
  }

  // MARK: - Output management

  func selectOutput(id: String) {
    selectedOutputID = id
    rebuildStateFromSelectedOutput()
  }

  func addOutput() {
    let seed = selectedOutput ?? configuration.effectiveOutputs.first ?? .default
    var output = seed
    output.id = UUID().uuidString
    output.name = uniqueOutputName(basedOn: seed.name == "Console" ? "Output" : seed.name)
    output.route = .console
    configuration.outputs.append(output)
    selectedOutputID = output.id
    rebuildState(from: output.logFormat)
    saveToStorage()
  }

  func duplicateSelectedOutput() {
    guard let selectedOutput else { return }
    var output = selectedOutput
    output.id = UUID().uuidString
    output.name = uniqueOutputName(basedOn: "\(selectedOutput.name) Copy")
    configuration.outputs.append(output)
    selectedOutputID = output.id
    rebuildState(from: output.logFormat)
    saveToStorage()
  }

  func removeSelectedOutput() {
    guard configuration.outputs.count > 1, let selectedOutputIndex else { return }
    configuration.outputs.remove(at: selectedOutputIndex)
    selectedOutputID = configuration.outputs[min(selectedOutputIndex, configuration.outputs.count - 1)].id
    rebuildStateFromSelectedOutput()
    saveToStorage()
  }

  func updateSelectedOutputName(_ name: String) {
    updateSelectedOutput { output in
      output.name = name.isEmpty ? "Output" : name
    }
  }

  func updateSelectedOutputRoute(_ rawValue: String) {
    updateSelectedOutput { output in
      output.route = AutoLogRoute(rawValue.isEmpty ? "console" : rawValue)
    }
  }

  func updateSelectedOutputEnabled(_ enabled: Bool) {
    updateSelectedOutput { output in
      output.isEnabled = enabled
    }
  }

  func updateSelectedOutputMeasureTiming(_ enabled: Bool) {
    updateSelectedOutput { output in
      output.measureTiming = enabled
    }
  }

  func updateSelectedOutputErrorContextLimit(_ limit: Int) {
    updateSelectedOutput { output in
      output.errorContextLimit = max(0, limit)
    }
  }

  func updateSelectedOutputTypeFilters(from rawValue: String) {
    let filters = rawValue
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }

    updateSelectedOutput { output in
      output.typeNameFilters = filters
    }
  }

  func updateSelectedOutputTimingDepths(_ rawValue: String) {
    let values = Set(
      rawValue
        .split(separator: ",")
        .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    )

    updateSelectedOutput { output in
      output.timingDepths = values.isEmpty ? nil : values
    }
  }

  func toggleSelectedOutputEventType(_ eventType: AutoLogOutputEventType, isOn: Bool) {
    updateSelectedOutput { output in
      if isOn {
        output.eventTypes.insert(eventType)
      } else {
        output.eventTypes.remove(eventType)
      }
    }
  }

  // MARK: - Format mutations

  func activate(_ element: LogFormat.Element, at index: Int) {
    let clamped = min(index, activeElements.count)
    activeElements.insert(element, at: clamped)
    if !element.isSpacer {
      inactiveElements.removeAll { $0 == element }
    }
    persistCurrentFormat()
  }

  func deactivate(at index: Int) {
    guard activeElements.indices.contains(index) else { return }
    let element = activeElements.remove(at: index)
    if !element.isSpacer, !inactiveElements.contains(element) {
      inactiveElements.append(element)
      sortInactive()
    }
    persistCurrentFormat()
  }

  func moveInActive(from fromIndex: Int, to toIndex: Int) {
    guard fromIndex != toIndex,
          activeElements.indices.contains(fromIndex) else { return }
    let element = activeElements.remove(at: fromIndex)
    let destination = min(fromIndex < toIndex ? toIndex - 1 : toIndex, activeElements.count)
    activeElements.insert(element, at: destination)
    persistCurrentFormat()
  }

  func updateArrowStyle(_ style: LogFormat.ArrowStyle) {
    arrowStyle = style
    persistCurrentFormat()
  }

  func updateStatusStyle(_ style: LogFormat.StatusStyle) {
    statusStyle = style
    persistCurrentFormat()
  }

  // MARK: - Code snippet

  var codeSnippet: String {
    let outputsSnippet = configuration.outputs
      .map(renderOutputSnippet)
      .joined(separator: ",\n")

    return """
    AutoLog.start(
      configuration: AutoLogConfiguration(
        emitStartEvents: \(configuration.emitStartEvents),
        measureTimingDefault: \(configuration.measureTimingDefault),
        deduplicateWithin: \(renderDeduplication(configuration.deduplicateWithin)),
        measureTimingDepths: \(renderDepths(configuration.measureTimingDepths)),
        logFormat: \(renderLogFormat(configuration.logFormat)),
        outputs: [
    \(indent(outputsSnippet, spaces: 10))
        ]
      )
    )
    """
  }

  // MARK: - Private helpers

  private func persistCurrentFormat() {
    updateSelectedOutput { output in
      output.logFormat = currentFormat
    }
  }

  private func updateSelectedOutput(_ mutate: (inout AutoLogOutput) -> Void) {
    guard let selectedOutputIndex else { return }
    mutate(&configuration.outputs[selectedOutputIndex])
    saveToStorage()
  }

  private func ensureSelection() {
    if let existing = configuration.outputs.first(where: { $0.id == selectedOutputID }) {
      selectedOutputID = existing.id
    } else {
      selectedOutputID = configuration.outputs.first?.id ?? ""
    }
  }

  private func rebuildStateFromSelectedOutput() {
    ensureSelection()
    rebuildState(from: selectedOutput?.logFormat ?? .default)
  }

  private func rebuildState(from format: LogFormat) {
    activeElements = format.mainLine
    arrowStyle = format.arrowStyle
    statusStyle = format.statusStyle

    let activeDataSet = Set(format.mainLine.filter { !$0.isSpacer })
    let dataInPalette = LogFormat.Element.allCases.filter {
      !$0.isSpacer && !activeDataSet.contains($0)
    }
    let spacersInPalette = LogFormat.Element.allCases.filter { $0.isSpacer }
    inactiveElements = dataInPalette + spacersInPalette
  }

  private func sortInactive() {
    let order = LogFormat.Element.allCases
    inactiveElements.sort { order.firstIndex(of: $0)! < order.firstIndex(of: $1)! }
  }

  private func synchronizeLegacyFields(in configuration: AutoLogConfiguration) -> AutoLogConfiguration {
    var configuration = configuration
    let sourceOutput = configuration.outputs.first(where: { $0.route == .console }) ?? configuration.outputs.first
    if let sourceOutput {
      configuration.logFormat = sourceOutput.logFormat
      configuration.measureTimingDefault = sourceOutput.measureTiming
      configuration.measureTimingDepths = sourceOutput.timingDepths
    }
    return configuration
  }

  private func uniqueOutputName(basedOn base: String) -> String {
    let existing = Set(configuration.outputs.map(\.name))
    guard existing.contains(base) else { return base }

    for number in 2...99 where !existing.contains("\(base) \(number)") {
      return "\(base) \(number)"
    }

    return "\(base) \(UUID().uuidString.prefix(4))"
  }

  private func renderOutputSnippet(_ output: AutoLogOutput) -> String {
    let eventTypes = output.eventTypes
      .sorted { $0.rawValue < $1.rawValue }
      .map { ".\($0.rawValue)" }
      .joined(separator: ", ")

    return """
    AutoLogOutput(
      id: \(literal(output.id)),
      name: \(literal(output.name)),
      route: AutoLogRoute(\(literal(output.route.rawValue))),
      isEnabled: \(output.isEnabled),
      eventTypes: [\(eventTypes)],
      typeNameFilters: [\(output.typeNameFilters.map(literal).joined(separator: ", "))],
      measureTiming: \(output.measureTiming),
      timingDepths: \(renderDepths(output.timingDepths)),
      errorContextLimit: \(output.errorContextLimit),
      logFormat: \(renderLogFormat(output.logFormat))
    )
    """
  }

  private func renderLogFormat(_ format: LogFormat) -> String {
    let list = format.mainLine.map { ".\($0.rawValue)" }.joined(separator: ", ")
    return """
    LogFormat(
      mainLine: [\(list)],
      arrowStyle: \(renderArrowStyle(format.arrowStyle)),
      statusStyle: \(renderStatusStyle(format.statusStyle))
    )
    """
      .replacingOccurrences(of: "\n", with: " ")
      .replacingOccurrences(of: "  ", with: " ")
  }

  private func renderDepths(_ depths: Set<Int>?) -> String {
    guard let depths else { return "nil" }
    return "[" + depths.sorted().map(\.description).joined(separator: ", ") + "]"
  }

  private func renderDeduplication(_ deduplication: AutoLogDeduplication?) -> String {
    guard let deduplication else { return "nil" }
    let seconds = Double(deduplication.milliseconds) / 1_000
    return ".seconds(\(seconds.formatted(.number.precision(.fractionLength(0...3)))))"
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

  private func indent(_ value: String, spaces: Int) -> String {
    let prefix = String(repeating: " ", count: spaces)
    return value
      .split(separator: "\n", omittingEmptySubsequences: false)
      .map { prefix + $0 }
      .joined(separator: "\n")
  }
}
