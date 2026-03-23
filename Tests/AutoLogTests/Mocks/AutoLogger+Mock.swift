import AutoLog

final class MockLogger: AutoLogger, @unchecked Sendable {
  var events: [AutoLogEvent]

  func emit(event: AutoLogEvent) {
    self.events.append(event)
  }

  init(events: [AutoLogEvent] = []) {
    self.events = events
  }
}

extension AutoLogger where Self == MockLogger {
  static var mock: any AutoLogger {
    MockLogger()
  }
}
