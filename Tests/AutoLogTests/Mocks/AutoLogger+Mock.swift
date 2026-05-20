import AutoLog

final class MockLogger: AutoLogger, @unchecked Sendable {
  var events: [AutoLogEvent]
  var configurations: [AutoLogConfiguration]

  func emit(event: AutoLogEvent, configuration: AutoLogConfiguration) {
    self.events.append(event)
    self.configurations.append(configuration)
  }

  init(events: [AutoLogEvent] = []) {
    self.events = events
    self.configurations = []
  }
}

extension AutoLogger where Self == MockLogger {
  static var mock: any AutoLogger {
    MockLogger()
  }
}

extension AutoLogConfiguration {
  static var testConsoleWithoutStart: AutoLogConfiguration {
    AutoLogConfiguration(
      outputs: [
        AutoLogOutput(
          name: "Console",
          route: .console,
          eventTypes: [.interaction, .success, .failure, .warning]
        )
      ]
    )
  }
}
