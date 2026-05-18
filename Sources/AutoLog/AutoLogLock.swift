import Foundation

// TODO: Reconsider `Synchronization.Mutex` once iOS 18 is old enough to become
// the package's minimum supported iOS version.
final class AutoLogLock<Value>: @unchecked Sendable {
  private let lock = NSLock()
  private var value: Value

  init(_ value: Value) {
    self.value = value
  }

  func withLock<Result>(_ body: (inout Value) throws -> Result) rethrows -> Result {
    lock.lock()
    defer { lock.unlock() }
    return try body(&value)
  }
}
