import AutoLogMacro
import MacroTesting
import Testing

@Suite(
  .macros(
    [OSLogMacro.self],
    indentationWidth: .spaces(2),
    record: .missing
  )
)
struct OSLogMacroTests {
  @Test
  func function_default_noAdditionalAnnotations() throws {
    assertMacro {
      #"""
      @OSLog
      func foo() { 
        print("Foo")
      }
      """#
    } expansion: {
      """
      func foo() {
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = Self.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func foo()",
          parameters: [:],
          tags: []
        )
        autoLogger.emitStart(event: event, configuration: runtime.configuration, deduplicator: runtime.deduplicator)
        let __logStart = ContinuousClock.now
        func _foo() {
          print("Foo")
        }
        let _ = _foo()
        event.duration = ContinuousClock.now - __logStart
        autoLogger.emitIfEnabled(event: event, configuration: runtime.configuration, deduplicator: runtime.deduplicator)
      }
      """
    }
  }

  @Test
  func intFunctionWithVariadicParameters_taggableAsStringLiteralType_noAdditionalAnnotations() throws {
    assertMacro {
      #"""
      @OSLog(tag: "example")
      func sum(numbers: Int...) -> Int {
        return numbers.reduce(0, +)
      }
      """#
    } expansion: {
      """
      func sum(numbers: Int...) -> Int {
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = Self.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func sum(numbers: Int...) -> Int",
          singleParameterLabel: "numbers",
          singleParameterValue: numbers,
          tags: ["example"]
        )
        autoLogger.emitStart(event: event, configuration: runtime.configuration, deduplicator: runtime.deduplicator)
        let __logStart = ContinuousClock.now
        func _sum(numbers: Int...) -> Int {
          return numbers.reduce(0, +)
        }
        let result = _sum(numbers: numbers)
        event.result = .success(result)
        event.duration = ContinuousClock.now - __logStart
        autoLogger.emitIfEnabled(event: event, configuration: runtime.configuration, deduplicator: runtime.deduplicator)
        return result
      }
      """
    }
  }

  @Test
  func functionWithArguments_allTraits_noAdditionalAnnotations() throws {
    assertMacro {
      #"""
      @OSLog(level: .debug, omit: .result, .parameters, tag: .commonTag, "example")
      func transform(value: Int, using transform: (Int) -> String) -> String {
        return transform(value)
      }
      """#
    } expansion: {
      """
      func transform(value: Int, using transform: (Int) -> String) -> String {
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = Self.logger
        var event = AutoLogEvent(
          level: .debug,
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func transform(value: Int, using transform: (Int) -> String) -> String",
          tags: [.commonTag, "example"]
        )
        autoLogger.emitStart(event: event, configuration: runtime.configuration, deduplicator: runtime.deduplicator)
        let __logStart = ContinuousClock.now
        func _transform(value: Int, transform: (Int) -> String) -> String {
          return transform(value)
        }
        let result = _transform(value: value, transform: transform)
        event.duration = ContinuousClock.now - __logStart
        autoLogger.emitIfEnabled(event: event, configuration: runtime.configuration, deduplicator: runtime.deduplicator)
        return result
      }
      """
    }
  }

  @Test
  func function_default_withMultipleTagAnnotations_preservesSourceOrder() throws {
    assertMacro {
      #"""
      @Tag("example")
      @Tag(.commonTag)
      @OSLog
      func ping() {}
      """#
    } expansion: {
      """
      @Tag("example")
      @Tag(.commonTag)
      func ping() {
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = Self.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func ping()",
          parameters: [:],
          tags: ["example", .commonTag]
        )
        autoLogger.emitStart(event: event, configuration: runtime.configuration, deduplicator: runtime.deduplicator)
        let __logStart = ContinuousClock.now
        func _ping() {
        }
        let _ = _ping()
        event.duration = ContinuousClock.now - __logStart
        autoLogger.emitIfEnabled(event: event, configuration: runtime.configuration, deduplicator: runtime.deduplicator)
      }
      """
    }
  }
}
