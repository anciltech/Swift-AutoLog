import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Snapshot of the execution context at the moment a log event is emitted.
public struct AutoLogExecutionContext: Sendable, Equatable, Codable, CustomStringConvertible {
  public var threadLabel: String
  public var threadID: UInt64?
  public var taskID: String?

  public init(
    threadLabel: String,
    threadID: UInt64? = nil,
    taskID: String? = nil
  ) {
    self.threadLabel = threadLabel
    self.threadID = threadID
    self.taskID = taskID
  }

  public static func capture() -> Self {
    capture(needsThreadID: true, needsTaskID: true)
  }

  public static func minimalCurrent() -> Self {
    AutoLogExecutionContext(threadLabel: Thread.isMainThread ? "main" : "bg")
  }

  public static func capture(
    needsThreadID: Bool,
    needsTaskID: Bool
  ) -> Self {
    AutoLogExecutionContext(
      threadLabel: Thread.isMainThread ? "main" : "bg",
      threadID: needsThreadID ? currentThreadID() : nil,
      taskID: needsTaskID ? currentTaskID() : nil
    )
  }

  public var abbreviatedThreadID: String? {
    guard let threadID else { return nil }
    let hex = String(threadID, radix: 16, uppercase: true)
    return "#\(String(hex.suffix(4)))"
  }

  public var description: String {
    [
      threadLabel,
      abbreviatedThreadID,
      taskID,
    ]
      .compactMap { $0 }
      .joined(separator: " ")
  }

  private static func currentTaskID() -> String? {
    withUnsafeCurrentTask { task in
      guard let task else { return nil }
      let description = String(describing: task)
      guard let prefixRange = description.range(of: "0x") else {
        return "T:current"
      }

      let hex = description[prefixRange.upperBound...].prefix { $0.isHexDigit }
      guard !hex.isEmpty else { return "T:current" }
      return "T:\(String(hex.suffix(4)).uppercased())"
    }
  }

  private static func currentThreadID() -> UInt64? {
    #if canImport(Darwin)
    var threadID: UInt64 = 0
    pthread_threadid_np(nil, &threadID)
    return threadID
    #else
    return nil
    #endif
  }
}
