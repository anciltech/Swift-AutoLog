import AutoLogMacro
import MacroTesting
import Testing

@Suite(
  .macros(
    [LogMacro.self],
    indentationWidth: .spaces(2),
    record: .missing
  )
)
struct LogMacroTests {
  @Test
  func voidFunction_default_noAdditinalAnnotations() throws {
    assertMacro {
      #"""
      @Log
      func foo() { 
        print("Foo")
      }
      """#
    } expansion: {
      """
      func foo() {
        let autoLogger: any AutoLogger = AutoLogSource.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func foo()",
          parameters: [:],
          tags: []
        )
        autoLogger.emitStart(event: event)
        let __logStart = ContinuousClock.now
        print("Foo")
        event.duration = ContinuousClock.now - __logStart
        autoLogger.emit(event: event)
      }
      """
    }
  }

  @Test
  func voidFunction_lggableAsInitializer_noAdditionalAnnotations() throws {
    assertMacro {
      #"""
      @Log(using: CustomLogger())
      func foo() { 
        print("Foo")
      }
      """#
    } expansion: {
      """
      func foo() {
        let autoLogger: any AutoLogger = CustomLogger()
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func foo()",
          parameters: [:],
          tags: []
        )
        autoLogger.emitStart(event: event)
        let __logStart = ContinuousClock.now
        print("Foo")
        event.duration = ContinuousClock.now - __logStart
        autoLogger.emit(event: event)
      }
      """
    }
  }

  @Test
  func voidFunction_autoLoggerAsStaticParameter_noAdditionalAnnotations() throws {
    assertMacro {
      #"""
      @Log(using: .custom)
      func foo() { 
        print("Foo")
      }
      """#
    } expansion: {
      """
      func foo() {
        let autoLogger: any AutoLogger = .custom
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func foo()",
          parameters: [:],
          tags: []
        )
        autoLogger.emitStart(event: event)
        let __logStart = ContinuousClock.now
        print("Foo")
        event.duration = ContinuousClock.now - __logStart
        autoLogger.emit(event: event)
      }
      """
    }
  }

  @Test
  func stringFunction_default_noAdditionalAnnotations() throws {
    assertMacro {
      #"""
      @Log
      func foo() -> String { 
        return "Foo"
      }
      """#
    } expansion: {
      """
      func foo() -> String {
        let autoLogger: any AutoLogger = AutoLogSource.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func foo() -> String",
          parameters: [:],
          tags: []
        )
        autoLogger.emitStart(event: event)
        let __logStart = ContinuousClock.now
        func _foo() -> String {
          return "Foo"
        }
        let result = _foo()
        event.result = .success(result)
        event.duration = ContinuousClock.now - __logStart
        autoLogger.emit(event: event)
        return result
      }
      """
    }
  }

  @Test
  func stringFunctionWithArguments_autoLoggerAndLevelableAsStaticParameters_noAdditionalAnnotations() throws {
    assertMacro {
      #"""
      @Log(using: .foo, level: .debug)
      func foo(bar: String) -> String { 
        print("Foo: \(bar)")
      }
      """#
    } expansion: {
      #"""
      func foo(bar: String) -> String {
        let autoLogger: any AutoLogger = .foo
        var event = AutoLogEvent(
          level: .debug,
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func foo(bar: String) -> String",
          parameters: [
            "bar": bar
          ],
          tags: []
        )
        autoLogger.emitStart(event: event)
        let __logStart = ContinuousClock.now
        func _foo(bar: String) -> String {
          print("Foo: \(bar)")
        }
        let result = _foo(bar: bar)
        event.result = .success(result)
        event.duration = ContinuousClock.now - __logStart
        autoLogger.emit(event: event)
        return result
      }
      """#
    }
  }

  @Test
  func stringFunctionWithArgument_taggableAsStringLiteralType_noAdditionalAnnotations() throws {
    assertMacro {
      #"""
      @Log(tag: "example")
      func foo(bar: String) -> String { 
        return "Foo: \(bar)"
      }
      """#
    } expansion: {
      #"""
      func foo(bar: String) -> String {
        let autoLogger: any AutoLogger = AutoLogSource.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func foo(bar: String) -> String",
          parameters: [
            "bar": bar
          ],
          tags: ["example"]
        )
        autoLogger.emitStart(event: event)
        let __logStart = ContinuousClock.now
        func _foo(bar: String) -> String {
          return "Foo: \(bar)"
        }
        let result = _foo(bar: bar)
        event.result = .success(result)
        event.duration = ContinuousClock.now - __logStart
        autoLogger.emit(event: event)
        return result
      }
      """#
    }
  }

  @Test
  func tupleFunctionWithLabeledArguments_default_noAdditionalAnnotations() throws {
    assertMacro {
      #"""
      @Log
      func foo(_ bar: String, baz biz: Int) -> (String, Int) { 
        return ("Bar: \(bar)", biz * 2) 
      }
      """#
    } expansion: {
      #"""
      func foo(_ bar: String, baz biz: Int) -> (String, Int) {
        let autoLogger: any AutoLogger = AutoLogSource.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func foo(_ bar: String, baz biz: Int) -> (String, Int)",
          parameters: [
            "bar": bar,
            "biz": biz
          ],
          tags: []
        )
        autoLogger.emitStart(event: event)
        let __logStart = ContinuousClock.now
        func _foo(bar: String, biz: Int) -> (String, Int) {
          return ("Bar: \(bar)", biz * 2)
        }
        let result = _foo(bar: bar, biz: biz)
        event.result = .success(result)
        event.duration = ContinuousClock.now - __logStart
        autoLogger.emit(event: event)
        return result
      }
      """#
    }
  }

  @Test
  func mutatingFunction_default_withLevelAnnotation() throws {
    assertMacro {
      #"""
      @Level(.debug)
      @Log
      mutating func foo() { 
        self.counter += 1 
      }
      """#
    } expansion: {
      """
      @Level(.debug)
      mutating func foo() {
        let autoLogger: any AutoLogger = AutoLogSource.logger
        var event = AutoLogEvent(
          level: .debug,
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "mutating func foo()",
          parameters: [:],
          tags: []
        )
        autoLogger.emitStart(event: event)
        let __logStart = ContinuousClock.now
        self.counter += 1
        event.duration = ContinuousClock.now - __logStart
        autoLogger.emit(event: event)
      }
      """
    }
  }

  @Test
  func mutatingFunctionWithArgument_taggableAndLevelableAsPrameters_noAdditionalAnnotations() throws {
    assertMacro {
      #"""
      @Log(level: .debug, tag: .common, "example")
      mutating func foo(bar: String) { 
        self.bar = bar
      }
      """#
    } expansion: {
      """
      mutating func foo(bar: String) {
        let autoLogger: any AutoLogger = AutoLogSource.logger
        var event = AutoLogEvent(
          level: .debug,
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "mutating func foo(bar: String)",
          parameters: [
            "bar": bar
          ],
          tags: [.common, "example"]
        )
        autoLogger.emitStart(event: event)
        let __logStart = ContinuousClock.now
        self.bar = bar
        event.duration = ContinuousClock.now - __logStart
        autoLogger.emit(event: event)
      }
      """
    }
  }

  @Test
  func mutatingThrowingFunction_default_noAdditionalAnnotations() throws {
    assertMacro {
      #"""
      @Log
      mutating func foo() throws {
        if self.counter == 0 {
          throw NSError(domain: com.foo.test, code: .zero)
        } else {
          self.counter -= 1
        }
      }
      """#
    } expansion: {
      """
      mutating func foo() throws {
        let autoLogger: any AutoLogger = AutoLogSource.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "mutating func foo() throws",
          parameters: [:],
          tags: []
        )
        autoLogger.emitStart(event: event)
        let __logStart = ContinuousClock.now
        func _foo() throws {
          if self.counter == 0 {
            throw NSError(domain: com.foo.test, code: .zero)
          } else {
            self.counter -= 1
          }
        }
        do {
          let _ = try _foo()
          event.duration = ContinuousClock.now - __logStart
          autoLogger.emit(event: event)
        } catch {
          event.result = .failure(error)
          event.duration = ContinuousClock.now - __logStart
          autoLogger.emit(event: event)
          throw error
        }
      }
      """
    }
  }

  @Test
  func throwingFunction_default_withTagAndLevelAnnotations() throws {
    assertMacro {
      #"""
      @Level(.error)
      @Tag("example")
      @Log
      func foo() throws {
        throw NSError()
      }
      """#
    } expansion: {
      """
      @Level(.error)
      @Tag("example")
      func foo() throws {
        let autoLogger: any AutoLogger = AutoLogSource.logger
        var event = AutoLogEvent(
          level: .error,
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func foo() throws",
          parameters: [:],
          tags: ["example"]
        )
        autoLogger.emitStart(event: event)
        let __logStart = ContinuousClock.now
        func _foo() throws {
          throw NSError()
        }
        do {
          let _ = try _foo()
          event.duration = ContinuousClock.now - __logStart
          autoLogger.emit(event: event)
        } catch {
          event.result = .failure(error)
          event.duration = ContinuousClock.now - __logStart
          autoLogger.emit(event: event)
          throw error
        }
      }
      """
    }
  }

  @Test
  func throwingFunction_default_noAdditionalAnnotations() throws {
    assertMacro {
      #"""
      @Log
      func foo() throws -> Int {
        if Bool.random() {
          throw NSError(domain: com.foo.test, code: .zero)
        } else {
          return .zero
        }
      }
      """#
    } expansion: {
      """
      func foo() throws -> Int {
        let autoLogger: any AutoLogger = AutoLogSource.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func foo() throws -> Int",
          parameters: [:],
          tags: []
        )
        autoLogger.emitStart(event: event)
        let __logStart = ContinuousClock.now
        func _foo() throws -> Int {
          if Bool.random() {
            throw NSError(domain: com.foo.test, code: .zero)
          } else {
            return .zero
          }
        }
        do {
          let result = try _foo()
          event.result = .success(result)
          event.duration = ContinuousClock.now - __logStart
          autoLogger.emit(event: event)
          return result
        } catch {
          event.result = .failure(error)
          event.duration = ContinuousClock.now - __logStart
          autoLogger.emit(event: event)
          throw error
        }
      }
      """
    }
  }

  @Test
  func throwingFunctionWithArgument_default_withOmitParameterAnnotation() throws {
    assertMacro {
      #"""
      @Omit("value")
      @Log
      func foo(_ value: Int) throws {
        if Bool.random() {
          print("true")
          throw NSError(domain: com.foo.test, code: .zero)
        } else {
          print("false")
        }
      }
      """#
    } expansion: {
      """
      @Omit("value")
      func foo(_ value: Int) throws {
        let autoLogger: any AutoLogger = AutoLogSource.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func foo(_ value: Int) throws",
          parameters: [
            :
          ],
          tags: []
        )
        autoLogger.emitStart(event: event)
        let __logStart = ContinuousClock.now
        func _foo(value: Int) throws {
          if Bool.random() {
            print("true")
            throw NSError(domain: com.foo.test, code: .zero)
          } else {
            print("false")
          }
        }
        do {
          let _ = try _foo(value: value)
          event.duration = ContinuousClock.now - __logStart
          autoLogger.emit(event: event)
        } catch {
          event.result = .failure(error)
          event.duration = ContinuousClock.now - __logStart
          autoLogger.emit(event: event)
          throw error
        }
      }
      """
    }
  }

  @Test
  func throwingFunctionWithArguments_omittableAsStaticParameter_noAdditionalAnnotations() throws {
    assertMacro {
      #"""
      @Log(omit: .parameters)
      func foo(_ value: Int, content: String) throws -> (Int, String) {
        if Bool.random() {
          throw NSError(domain: com.foo.test, code: .zero)
        } else {
          return (value, "\(content): \(value)")
        }
      }
      """#
    } expansion: {
      #"""
      func foo(_ value: Int, content: String) throws -> (Int, String) {
        let autoLogger: any AutoLogger = AutoLogSource.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func foo(_ value: Int, content: String) throws -> (Int, String)",
          tags: []
        )
        autoLogger.emitStart(event: event)
        let __logStart = ContinuousClock.now
        func _foo(value: Int, content: String) throws -> (Int, String) {
          if Bool.random() {
            throw NSError(domain: com.foo.test, code: .zero)
          } else {
            return (value, "\(content): \(value)")
          }
        }
        do {
          let result = try _foo(value: value, content: content)
          event.result = .success(result)
          event.duration = ContinuousClock.now - __logStart
          autoLogger.emit(event: event)
          return result
        } catch {
          event.result = .failure(error)
          event.duration = ContinuousClock.now - __logStart
          autoLogger.emit(event: event)
          throw error
        }
      }
      """#
    }
  }

  @Test
  func asyncThrowingFunction_levelableAsStringLiteralTypeParameter_withTagAnnotation() throws {
    assertMacro {
      #"""
      @Tag("example")
      @Log(level: "fault")
      func foo() async throws {
        try await Task.sleep(nanoseconds: 100_000_000)
      }
      """#
    } expansion: {
      """
      @Tag("example")
      func foo() async throws {
        let autoLogger: any AutoLogger = AutoLogSource.logger
        var event = AutoLogEvent(
          level: "fault",
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func foo() async throws",
          parameters: [:],
          tags: ["example"]
        )
        autoLogger.emitStart(event: event)
        let __logStart = ContinuousClock.now
        func _foo() async throws {
          try await Task.sleep(nanoseconds: 100_000_000)
        }
        do {
          let _ = try await _foo()
          event.duration = ContinuousClock.now - __logStart
          autoLogger.emit(event: event)
        } catch {
          event.result = .failure(error)
          event.duration = ContinuousClock.now - __logStart
          autoLogger.emit(event: event)
          throw error
        }
      }
      """
    }
  }

  @Test
  func functionWithEscapingClosure_default_noAdditionalAnnotations() throws {
    assertMacro {
      #"""
      @Log
      func performTask(completion: @escaping () -> Void) {
        completion()
      }
      """#
    } expansion: {
      """
      func performTask(completion: @escaping () -> Void) {
        let autoLogger: any AutoLogger = AutoLogSource.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func performTask(completion: @escaping () -> Void)",
          parameters: [
            "completion": completion
          ],
          tags: []
        )
        autoLogger.emitStart(event: event)
        let __logStart = ContinuousClock.now
        completion()
        event.duration = ContinuousClock.now - __logStart
        autoLogger.emit(event: event)
      }
      """
    }
  }

  @Test
  func functionWithAutoclosureArgument_omittableAsStaticParameter_withLevelAnnotation() throws {
    assertMacro {
      #"""
      @Level(.info)
      @Log(omit: .result)
      func check(condition: @autoclosure () -> Bool) -> Bool {
        return condition()
      }
      """#
    } expansion: {
      """
      @Level(.info)
      func check(condition: @autoclosure () -> Bool) -> Bool {
        let autoLogger: any AutoLogger = AutoLogSource.logger
        var event = AutoLogEvent(
          level: .info,
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func check(condition: @autoclosure () -> Bool) -> Bool",
          parameters: [
            "condition": condition
          ],
          tags: []
        )
        autoLogger.emitStart(event: event)
        let __logStart = ContinuousClock.now
        func _check(condition: @autoclosure () -> Bool) -> Bool {
          return condition()
        }
        let result = _check(condition: condition())
        event.duration = ContinuousClock.now - __logStart
        autoLogger.emit(event: event)
        return result
      }
      """
    }
  }

  @Test
  func functionWithInoutArgument_default_noAdditionalAnnotations() throws {
    assertMacro {
      #"""
      @Log
      func update(value: inout Int, with newValue: Int) {
        value = newValue
      }
      """#
    } expansion: {
      """
      func update(value: inout Int, with newValue: Int) {
        let autoLogger: any AutoLogger = AutoLogSource.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func update(value: inout Int, with newValue: Int)",
          parameters: [
            "value": value,
            "newValue": newValue
          ],
          tags: []
        )
        autoLogger.emitStart(event: event)
        let __logStart = ContinuousClock.now
        value = newValue
        event.duration = ContinuousClock.now - __logStart
        autoLogger.emit(event: event)
      }
      """
    }
  }

  @Test
  func staticFunctionWithArgument_omittableAsStringLiteralType_withOmitResultAnnotation() throws {
    assertMacro {
      #"""
      @Omit(.result)
      @Log(omit: "info")
      static func staticMethod(info: String) -> String {
        return "Static: \(info)"
      }
      """#
    } expansion: {
      #"""
      @Omit(.result)
      static func staticMethod(info: String) -> String {
        let autoLogger: any AutoLogger = AutoLogSource.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "static func staticMethod(info: String) -> String",
          parameters: [
            :
          ],
          tags: []
        )
        autoLogger.emitStart(event: event)
        let __logStart = ContinuousClock.now
        func _staticMethod(info: String) -> String {
          return "Static: \(info)"
        }
        let result = _staticMethod(info: info)
        event.duration = ContinuousClock.now - __logStart
        autoLogger.emit(event: event)
        return result
      }
      """#
    }
  }

  @Test
  func rethrowsFunctionWithClosureArgument_omittableAsStringLiteralType_withRedundatOmitParameterAnnotation() throws {
    assertMacro {
      #"""
      @Omit("operation")
      @Log(omit: "operation")
      func execute(operation: () throws -> Void) rethrows {
        try operation()
      }
      """#
    } expansion: {
      """
      @Omit("operation")
      func execute(operation: () throws -> Void) rethrows {
        let autoLogger: any AutoLogger = AutoLogSource.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func execute(operation: () throws -> Void) rethrows",
          parameters: [
            :
          ],
          tags: []
        )
        autoLogger.emitStart(event: event)
        let __logStart = ContinuousClock.now
        func _execute(operation: () throws -> Void) rethrows {
          try operation()
        }
        do {
          let _ = try _execute(operation: operation)
          event.duration = ContinuousClock.now - __logStart
          autoLogger.emit(event: event)
        } catch {
          event.result = .failure(error)
          event.duration = ContinuousClock.now - __logStart
          autoLogger.emit(event: event)
          throw error
        }
      }
      """
    }
  }

  @Test
  func functionWithArguments_allTraits_noAdditionalAnnotations() throws {
    assertMacro {
      #"""
      @Log(using: .custom, level: .debug, omit: .result, .parameters, tag: .commonTag, "example")
      func transform(value: Int, using transform: (Int) -> String) -> String {
        return transform(value)
      }
      """#
    } expansion: {
      """
      func transform(value: Int, using transform: (Int) -> String) -> String {
        let autoLogger: any AutoLogger = .custom
        var event = AutoLogEvent(
          level: .debug,
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func transform(value: Int, using transform: (Int) -> String) -> String",
          tags: [.commonTag, "example"]
        )
        autoLogger.emitStart(event: event)
        let __logStart = ContinuousClock.now
        func _transform(value: Int, transform: (Int) -> String) -> String {
          return transform(value)
        }
        let result = _transform(value: value, transform: transform)
        event.duration = ContinuousClock.now - __logStart
        autoLogger.emit(event: event)
        return result
      }
      """
    }
  }

// TODO: 23122K - Multiple @Tag macros have non-deterministic order
//  func genericFunction_default_withAllAnnotations() throws {
//    assertMacro {
//      #"""
//      @Omit(.result, "value")
//      @Tag("example")
//      @Tag(.commonTag)
//      @Level(.info)
//      @Log
//      func identity<T>(_ value: T) -> T {
//        return value
//      }
//      """#
//    } expansion: {
//      """
//      @Omit(.result, "value")
//      @Tag("example")
//      @Tag(.commonTag)
//      @Level(.info)
//      func identity<T>(_ value: T) -> T {
//        let autoLogger: any AutoLogger = AutoLogSource.logger
//        var event = AutoLogEvent(
//          level: "level_info",
//          location: "TestModule/Test.swift:5:1",
//          declaration: "func identity<T>(_ value: T) -> T",
//          tags: ["tag_commonTag", "tag_example"]
//        )
//        event.parameters = [
//          :
//        ]
//        func _identity(value: T) -> T {
//          return value
//        }
//        let result = _identity(value: value)
//        event.duration = ContinuousClock.now - __logStart
//        autoLogger.emit(event: event)
//        return result
//      }
//      """
//    }
//  }

  @Test
  func genericTupleFunctionWithWhereClauseAndArguments_default_withRedundantTagAnnotation() throws {
    assertMacro {
      #"""
      @Tag(.example, "example")
      @Log
      func combine<T, U>(first: T, second: U) -> (T, U) where T: CustomStringConvertible, U: CustomStringConvertible {
        return (first, second)
      }
      """#
    } expansion: {
      """
      @Tag(.example, "example")
      func combine<T, U>(first: T, second: U) -> (T, U) where T: CustomStringConvertible, U: CustomStringConvertible {
        let autoLogger: any AutoLogger = AutoLogSource.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func combine<T, U>(first: T, second: U) -> (T, U) where T: CustomStringConvertible, U: CustomStringConvertible",
          parameters: [
            "first": first,
            "second": second
          ],
          tags: [.example, "example"]
        )
        autoLogger.emitStart(event: event)
        let __logStart = ContinuousClock.now
        func _combine(first: T, second: U) -> (T, U) {
          return (first, second)
        }
        let result = _combine(first: first, second: second)
        event.result = .success(result)
        event.duration = ContinuousClock.now - __logStart
        autoLogger.emit(event: event)
        return result
      }
      """
    }
  }

  @Test
  func stringFunctionWithDefaultParameters_default_noAdditionalAnnotations() throws {
    assertMacro {
      #"""
      @Log
      func greet(name: String = "Guest") -> String {
        return "Hello, \(name)!"
      }
      """#
    } expansion: {
      #"""
      func greet(name: String = "Guest") -> String {
        let autoLogger: any AutoLogger = AutoLogSource.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: #"func greet(name: String = "Guest") -> String"#,
          parameters: [
            "name": name
          ],
          tags: []
        )
        autoLogger.emitStart(event: event)
        let __logStart = ContinuousClock.now
        func _greet(name: String) -> String {
          return "Hello, \(name)!"
        }
        let result = _greet(name: name)
        event.result = .success(result)
        event.duration = ContinuousClock.now - __logStart
        autoLogger.emit(event: event)
        return result
      }
      """#
    }
  }

  @Test
  func intFunctionWithVariadicParameters_default_noAdditionalAnnotations() throws {
    assertMacro {
      #"""
      @Log
      func sum(numbers: Int...) -> Int {
        return numbers.reduce(0, +)
      }
      """#
    } expansion: {
      """
      func sum(numbers: Int...) -> Int {
        let autoLogger: any AutoLogger = AutoLogSource.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func sum(numbers: Int...) -> Int",
          parameters: [
            "numbers": numbers
          ],
          tags: []
        )
        autoLogger.emitStart(event: event)
        let __logStart = ContinuousClock.now
        func _sum(numbers: Int...) -> Int {
          return numbers.reduce(0, +)
        }
        let result = _sum(numbers: numbers)
        event.result = .success(result)
        event.duration = ContinuousClock.now - __logStart
        autoLogger.emit(event: event)
        return result
      }
      """
    }
  }

  @Test
  func functionWithArgument_default_withDiscardableResultAndOmitResultAnnotations() throws {
    assertMacro {
      #"""
      @Omit(.result)
      @Log
      @discardableResult
      func compute(value: Int) -> Int {
        return value * value
      }
      """#
    } expansion: {
      """
      @Omit(.result)
      @discardableResult
      func compute(value: Int) -> Int {
        let autoLogger: any AutoLogger = AutoLogSource.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func compute(value: Int) -> Int",
          parameters: [
            "value": value
          ],
          tags: []
        )
        autoLogger.emitStart(event: event)
        let __logStart = ContinuousClock.now
        func _compute(value: Int) -> Int {
          return value * value
        }
        let result = _compute(value: value)
        event.duration = ContinuousClock.now - __logStart
        autoLogger.emit(event: event)
        return result
      }
      """
    }
  }

  @Test
  func intClosureFunction_default_noAdditionalAnnotations() throws {
    assertMacro {
      #"""
      @Log
      func makeIncrementer() -> (Int) -> Int {
        return { $0 + 1 }
      }
      """#
    } expansion: {
      """
      func makeIncrementer() -> (Int) -> Int {
        let autoLogger: any AutoLogger = AutoLogSource.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func makeIncrementer() -> (Int) -> Int",
          parameters: [:],
          tags: []
        )
        autoLogger.emitStart(event: event)
        let __logStart = ContinuousClock.now
        func _makeIncrementer() -> (Int) -> Int {
          return {
            $0 + 1
          }
        }
        let result = _makeIncrementer()
        event.result = .success(result)
        event.duration = ContinuousClock.now - __logStart
        autoLogger.emit(event: event)
        return result
      }
      """
    }
  }

  @Test
  func functionWithAsyncClosureArgument_default_noAdditionalAnnotations() throws {
    assertMacro {
      #"""
      @Log
      func fetchData(completion: @escaping () async -> String) {
        Task {
          let data = await completion()
          print(data)
        }
      }
      """#
    } expansion: {
      """
      func fetchData(completion: @escaping () async -> String) {
        let autoLogger: any AutoLogger = AutoLogSource.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func fetchData(completion: @escaping () async -> String)",
          parameters: [
            "completion": completion
          ],
          tags: []
        )
        autoLogger.emitStart(event: event)
        let __logStart = ContinuousClock.now
        Task {
            let data = await completion()
            print(data)
          }
        event.duration = ContinuousClock.now - __logStart
        autoLogger.emit(event: event)
      }
      """
    }
  }

  @Test
  func functionWithArgument_default_mainActorAnnotation() throws {
    assertMacro {
      #"""
      @Log
      @MainActor
      func updateUI(message: String) {
        print(message)
      }
      """#
    } expansion: {
      """
      @MainActor
      func updateUI(message: String) {
        let autoLogger: any AutoLogger = AutoLogSource.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func updateUI(message: String)",
          parameters: [
            "message": message
          ],
          tags: []
        )
        autoLogger.emitStart(event: event)
        let __logStart = ContinuousClock.now
        print(message)
        event.duration = ContinuousClock.now - __logStart
        autoLogger.emit(event: event)
      }
      """
    }
  }

  @Test
  func genericFunctionWithMultipleConstraints_default_noAdditionalAnnotations() throws {
    assertMacro {
      #"""
      @Log
      func process<T: Equatable, U: Numeric>(first: T, second: U) -> Bool {
        return true
      }
      """#
    } expansion: {
      """
      func process<T: Equatable, U: Numeric>(first: T, second: U) -> Bool {
        let autoLogger: any AutoLogger = AutoLogSource.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func process<T: Equatable, U: Numeric>(first: T, second: U) -> Bool",
          parameters: [
            "first": first,
            "second": second
          ],
          tags: []
        )
        autoLogger.emitStart(event: event)
        let __logStart = ContinuousClock.now
        func _process(first: T, second: U) -> Bool {
          return true
        }
        let result = _process(first: first, second: second)
        event.result = .success(result)
        event.duration = ContinuousClock.now - __logStart
        autoLogger.emit(event: event)
        return result
      }
      """
    }
  }

  @Test
  func function_default_objcAnnotation() throws {
    assertMacro {
      #"""
      @Log
      @objc
      func performAction() {
        print("Action performed")
      }
      """#
    } expansion: {
      """
      @objc
      func performAction() {
        let autoLogger: any AutoLogger = AutoLogSource.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func performAction()",
          parameters: [:],
          tags: []
        )
        autoLogger.emitStart(event: event)
        let __logStart = ContinuousClock.now
        print("Action performed")
        event.duration = ContinuousClock.now - __logStart
        autoLogger.emit(event: event)
      }
      """
    }
  }

  @Test
  func optionalIntFunction_default_noAdditionalAnnotations() throws {
    assertMacro {
      #"""
      @Log
      func getOptionalValue() -> Int? {
        return nil
      }
      """#
    } expansion: {
      """
      func getOptionalValue() -> Int? {
        let autoLogger: any AutoLogger = AutoLogSource.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func getOptionalValue() -> Int?",
          parameters: [:],
          tags: []
        )
        autoLogger.emitStart(event: event)
        let __logStart = ContinuousClock.now
        func _getOptionalValue() -> Int? {
          return nil
        }
        let result = _getOptionalValue()
        event.result = .success(result)
        event.duration = ContinuousClock.now - __logStart
        autoLogger.emit(event: event)
        return result
      }
      """
    }
  }

  @Test
  func stringFunctionWithAsyncThrowingClosureParameter_default_noAdditionalAnnotations() throws
  {
    assertMacro {
      #"""
      @Log
      func performAsyncTask(completion: @escaping () async throws -> String) async throws -> String {
        return try await completion()
      }
      """#
    } expansion: {
      """
      func performAsyncTask(completion: @escaping () async throws -> String) async throws -> String {
        let autoLogger: any AutoLogger = AutoLogSource.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func performAsyncTask(completion: @escaping () async throws -> String) async throws -> String",
          parameters: [
            "completion": completion
          ],
          tags: []
        )
        autoLogger.emitStart(event: event)
        let __logStart = ContinuousClock.now
        func _performAsyncTask(completion: @escaping () async throws -> String) async throws -> String {
          return try await completion()
        }
        do {
          let result = try await _performAsyncTask(completion: completion)
          event.result = .success(result)
          event.duration = ContinuousClock.now - __logStart
          autoLogger.emit(event: event)
          return result
        } catch {
          event.result = .failure(error)
          event.duration = ContinuousClock.now - __logStart
          autoLogger.emit(event: event)
          throw error
        }
      }
      """
    }
  }

  @Test
  func overridingStringFunction_default_noAdditionalAnnotations() throws {
    assertMacro {
      #"""
      @Log
      override func description() -> String {
        return "Override"
      }
      """#
    } expansion: {
      """
      override func description() -> String {
        let autoLogger: any AutoLogger = AutoLogSource.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "override func description() -> String",
          parameters: [:],
          tags: []
        )
        autoLogger.emitStart(event: event)
        let __logStart = ContinuousClock.now
        func _description() -> String {
          return "Override"
        }
        let result = _description()
        event.result = .success(result)
        event.duration = ContinuousClock.now - __logStart
        autoLogger.emit(event: event)
        return result
      }
      """
    }
  }

  @Test
  func functionWithInoutAndDefaultArgument_default_noAdditionalAnnotations() throws {
    assertMacro {
      #"""
      @Log
      func updateScore(score: inout Int, increment: Int = 1) {
        score += increment
      }
      """#
    } expansion: {
      """
      func updateScore(score: inout Int, increment: Int = 1) {
        let autoLogger: any AutoLogger = AutoLogSource.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func updateScore(score: inout Int, increment: Int = 1)",
          parameters: [
            "score": score,
            "increment": increment
          ],
          tags: []
        )
        autoLogger.emitStart(event: event)
        let __logStart = ContinuousClock.now
        score += increment
        event.duration = ContinuousClock.now - __logStart
        autoLogger.emit(event: event)
      }
      """
    }
  }

  @Test
  func functionWithOptionalArgument_default_noAdditionalAnnotations() throws {
    assertMacro {
      #"""
      @Log
      func optionalTest(value: String?) -> String {
        return value ?? "Default"
      }
      """#
    } expansion: {
      """
      func optionalTest(value: String?) -> String {
        let autoLogger: any AutoLogger = AutoLogSource.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func optionalTest(value: String?) -> String",
          parameters: [
            "value": value
          ],
          tags: []
        )
        autoLogger.emitStart(event: event)
        let __logStart = ContinuousClock.now
        func _optionalTest(value: String?) -> String {
          return value ?? "Default"
        }
        let result = _optionalTest(value: value)
        event.result = .success(result)
        event.duration = ContinuousClock.now - __logStart
        autoLogger.emit(event: event)
        return result
      }
      """
    }
  }
  
  @Test
  func genericFunctionWithComplexSignature_default_withOmitSecondParameterAnnotation() throws {
    assertMacro {
      #"""
      @Omit("second")
      @Log
      func merge<T, U>(_ first: [T], with second: [U]) -> [(T, U)]
        where T: Comparable, U: Comparable
      {
        return []
      }
      """#
    } expansion: {
      #"""
      @Omit("second")
      func merge<T, U>(_ first: [T], with second: [U]) -> [(T, U)]
        where T: Comparable, U: Comparable{
        let autoLogger: any AutoLogger = AutoLogSource.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func merge<T, U>(_ first: [T], with second: [U]) -> [(T, U)]\n  where T: Comparable, U: Comparable",
          parameters: [
            "first": first,

          ],
          tags: []
        )
        autoLogger.emitStart(event: event)
        let __logStart = ContinuousClock.now
        func _merge(first: [T], second: [U]) -> [(T, U)]
        {
          return []
        }
        let result = _merge(first: first, second: second)
        event.result = .success(result)
        event.duration = ContinuousClock.now - __logStart
        autoLogger.emit(event: event)
        return result
      }
      """#
    }
  }
  
  @Test
  func functionWithClosureDefaultValue_default_noAdditionalAnnotations() throws {
    assertMacro {
      #"""
      @Log
      func perform(action: (() -> Void)? = nil) {
        action?()
      }
      """#
    } expansion: {
      """
      func perform(action: (() -> Void)? = nil) {
        let autoLogger: any AutoLogger = AutoLogSource.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func perform(action: (() -> Void)? = nil)",
          parameters: [
            "action": action
          ],
          tags: []
        )
        autoLogger.emitStart(event: event)
        let __logStart = ContinuousClock.now
        action?()
        event.duration = ContinuousClock.now - __logStart
        autoLogger.emit(event: event)
      }
      """
    }
  }

  @Test
  func staticGenericFunction_default_withDiscardableResultAnnotation() throws {
    assertMacro {
      #"""
      @Log
      @discardableResult
      static func create<T>(value: T) -> [T] {
        return [value]
      }
      """#
    } expansion: {
      """
      @discardableResult
      static func create<T>(value: T) -> [T] {
        let autoLogger: any AutoLogger = AutoLogSource.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "static func create<T>(value: T) -> [T]",
          parameters: [
            "value": value
          ],
          tags: []
        )
        autoLogger.emitStart(event: event)
        let __logStart = ContinuousClock.now
        func _create(value: T) -> [T] {
          return [value]
        }
        let result = _create(value: value)
        event.result = .success(result)
        event.duration = ContinuousClock.now - __logStart
        autoLogger.emit(event: event)
        return result
      }
      """
    }
  }
  
  @Test
  func stringFunctionWithTupleParameter_default_noAdditionalAnnotations() throws {
    assertMacro {
      #"""
      @Log
      func process(pair: (Int, String)) -> String {
        return "\(pair.0) - \(pair.1)"
      }
      """#
    } expansion: {
      #"""
      func process(pair: (Int, String)) -> String {
        let autoLogger: any AutoLogger = AutoLogSource.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func process(pair: (Int, String)) -> String",
          parameters: [
            "pair": pair
          ],
          tags: []
        )
        autoLogger.emitStart(event: event)
        let __logStart = ContinuousClock.now
        func _process(pair: (Int, String)) -> String {
          return "\(pair.0) - \(pair.1)"
        }
        let result = _process(pair: pair)
        event.result = .success(result)
        event.duration = ContinuousClock.now - __logStart
        autoLogger.emit(event: event)
        return result
      }
      """#
    }
  }

  @Test
  func genericFunctionWithGenericClosureParameter_default_noAdditionalAnnotations() throws {
    assertMacro {
      #"""
      @Log
      func filterElements<T>(elements: [T], using predicate: (T) -> Bool) -> [T] {
        return elements.filter(predicate)
      }
      """#
    } expansion: {
      """
      func filterElements<T>(elements: [T], using predicate: (T) -> Bool) -> [T] {
        let autoLogger: any AutoLogger = AutoLogSource.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func filterElements<T>(elements: [T], using predicate: (T) -> Bool) -> [T]",
          parameters: [
            "elements": elements,
            "predicate": predicate
          ],
          tags: []
        )
        autoLogger.emitStart(event: event)
        let __logStart = ContinuousClock.now
        func _filterElements(elements: [T], predicate: (T) -> Bool) -> [T] {
          return elements.filter(predicate)
        }
        let result = _filterElements(elements: elements, predicate: predicate)
        event.result = .success(result)
        event.duration = ContinuousClock.now - __logStart
        autoLogger.emit(event: event)
        return result
      }
      """
    }
  }

  @Test
  func genericArrayfunctionWithGenericClosureArgument_default_noAdditionalAnnotations() throws
  {
    assertMacro {
      #"""
      @Log
      func filterElements<T>(elements: [T], using predicate: (T) -> Bool) -> [T] {
        return elements.filter(predicate)
      }
      """#
    } expansion: {
      """
      func filterElements<T>(elements: [T], using predicate: (T) -> Bool) -> [T] {
        let autoLogger: any AutoLogger = AutoLogSource.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func filterElements<T>(elements: [T], using predicate: (T) -> Bool) -> [T]",
          parameters: [
            "elements": elements,
            "predicate": predicate
          ],
          tags: []
        )
        autoLogger.emitStart(event: event)
        let __logStart = ContinuousClock.now
        func _filterElements(elements: [T], predicate: (T) -> Bool) -> [T] {
          return elements.filter(predicate)
        }
        let result = _filterElements(elements: elements, predicate: predicate)
        event.result = .success(result)
        event.duration = ContinuousClock.now - __logStart
        autoLogger.emit(event: event)
        return result
      }
      """
    }
  }
}
