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
  func initializer_default_logsCompletion() throws {
    assertMacro {
      #"""
      struct Project {
        let name: String

        @Log
        init(name: String) {
          self.name = name
        }
      }
      """#
    } expansion: {
      """
      struct Project {
        let name: String
        init(name: String) {
          let runtime = AutoLog.runtimeSnapshot()
          let autoLogger: any AutoLogger = runtime.logger
          var event = AutoLogEvent(
            source: AutoLogSource.current,

            location: "TestModule/Test.swift:4:3",
            declaration: "init(name: String)",
            parameters: [
              "name": name
            ]
          )
          autoLogger.emitStart(event: event, runtime: runtime)
          let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
          defer {
            if let __logStart {
              event.duration = ContinuousClock.now - __logStart
            }
            autoLogger.emitIfEnabled(event: event, runtime: runtime)
          }
          self.name = name
        }
      }
      """
    }
  }

  @Test
  func throwingInitializer_default_logsThrownError() throws {
    assertMacro {
      #"""
      struct Project {
        let name: String

        @Log
        init(name: String) throws {
          guard !name.isEmpty else {
            throw ProjectError.emptyName
          }
          self.name = name
        }
      }
      """#
    } expansion: {
      """
      struct Project {
        let name: String
        init(name: String) throws {
          let runtime = AutoLog.runtimeSnapshot()
          let autoLogger: any AutoLogger = runtime.logger
          var event = AutoLogEvent(
            source: AutoLogSource.current,

            location: "TestModule/Test.swift:4:3",
            declaration: "init(name: String) throws",
            parameters: [
              "name": name
            ]
          )
          autoLogger.emitStart(event: event, runtime: runtime)
          let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
          var __logError: (any Error)?
          defer {
            if let __logError {
              event.result = .failure(__logError)
            }
            if let __logStart {
              event.duration = ContinuousClock.now - __logStart
            }
            autoLogger.emitIfEnabled(event: event, runtime: runtime)
          }
          do {
              guard !name.isEmpty else {
                event.earlyExit = AutoLogEarlyExit(kind: AutoLogEarlyExit.Kind.guard, intent: .unknown, condition: "name.isEmpty", message: nil)
                throw ProjectError.emptyName
              }
              self.name = name
          } catch {
            __logError = error
            throw error
          }
        }
      }
      """
    }
  }

  @Test
  func failableInitializer_default_logsEarlyNilReturn() throws {
    assertMacro {
      #"""
      struct Project {
        let name: String

        @Log
        init?(name: String) {
          guard !name.isEmpty else {
            return nil
          }
          self.name = name
        }
      }
      """#
    } expansion: {
      """
      struct Project {
        let name: String
        init?(name: String) {
          let runtime = AutoLog.runtimeSnapshot()
          let autoLogger: any AutoLogger = runtime.logger
          var event = AutoLogEvent(
            source: AutoLogSource.current,

            location: "TestModule/Test.swift:4:3",
            declaration: "init?(name: String)",
            parameters: [
              "name": name
            ]
          )
          autoLogger.emitStart(event: event, runtime: runtime)
          let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
          defer {
            if let __logStart {
              event.duration = ContinuousClock.now - __logStart
            }
            autoLogger.emitIfEnabled(event: event, runtime: runtime)
          }
          guard !name.isEmpty else {
            event.earlyExit = AutoLogEarlyExit(kind: AutoLogEarlyExit.Kind.guard, intent: .unknown, condition: "name.isEmpty", message: nil)
            return nil
              }
          self.name = name
        }
      }
      """
    }
  }

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
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func foo()"
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _foo() {
          print("Foo")
        }
        let _ = _foo()
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
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
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = CustomLogger()
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func foo()"
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _foo() {
          print("Foo")
        }
        let _ = _foo()
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
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
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = .custom
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func foo()"
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _foo() {
          print("Foo")
        }
        let _ = _foo()
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
      }
      """
    }
  }

  @Test
  func voidFunction_customLoggerMeasureFalse_omitsTimingWork() throws {
    assertMacro {
      #"""
      @Log(using: customLogger, measure: false)
      func foo() {
        print("Foo")
      }
      """#
    } expansion: {
      """
      func foo() {
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = customLogger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func foo()"
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        func _foo() {
          print("Foo")
        }
        let _ = _foo()
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
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
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func foo() -> String"
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _foo() -> String {
          return "Foo"
        }
        let result = _foo()
        event.result = .success(result)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
        return result
      }
      """
    }
  }

  @Test
  func stringFunction_emitSuccessesOnly_skipsStartEvent() throws {
    assertMacro {
      #"""
      @Log(emit: "successesOnly")
      func foo() -> String {
        return "Foo"
      }
      """#
    } expansion: {
      """
      func foo() -> String {
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func foo() -> String"
        )
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _foo() -> String {
          return "Foo"
        }
        let result = _foo()
        event.result = .success(result)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
        return result
      }
      """
    }
  }

  @Test
  func stringFunction_emitTypedSuccesses_skipsStartEvent() throws {
    assertMacro {
      #"""
      @Log(emit: [.successes])
      func foo() -> String {
        return "Foo"
      }
      """#
    } expansion: {
      """
      func foo() -> String {
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func foo() -> String"
        )
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _foo() -> String {
          return "Foo"
        }
        let result = _foo()
        event.result = .success(result)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
        return result
      }
      """
    }
  }

  @Test
  func throwingFunction_emitFailuresOnly_skipsStartAndSuccessEvent() throws {
    assertMacro {
      #"""
      @Log(emit: "failuresOnly")
      func foo() throws -> String {
        try risky()
      }
      """#
    } expansion: {
      """
      func foo() throws -> String {
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func foo() throws -> String"
        )
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _foo() throws -> String {
          try risky()
        }
        do {
          let result = try _foo()
          return result
        } catch {
          event.result = .failure(error)
          if let __logStart {
            event.duration = ContinuousClock.now - __logStart
          }
          autoLogger.emitIfEnabled(event: event, runtime: runtime)
          throw error
        }
      }
      """
    }
  }

  @Test
  func boolFunction_withDeduplicateTrait_includesPerEventWindow() throws {
    assertMacro {
      #"""
      @Deduplicate(.seconds(1))
      @Log
      func hover(frameID: Int) -> Bool {
        return frameID.isMultiple(of: 2)
      }
      """#
    } expansion: {
      """
      @Deduplicate(.seconds(1))
      func hover(frameID: Int) -> Bool {
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func hover(frameID: Int) -> Bool",
          parameters: [
            "frameID": frameID
          ],
          deduplicateWithin: .seconds(1)
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _hover(frameID: Int) -> Bool {
          return frameID.isMultiple(of: 2)
        }
        let result = _hover(frameID: frameID)
        event.result = .success(result)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
        return result
      }
      """
    }
  }

  @Test
  func boolFunction_withWhenTrait_emitsOnlyMatchingSuccessValue() throws {
    assertMacro {
      #"""
      @When(true)
      @Log
      func isSelected(frameID: Int) -> Bool {
        return frameID.isMultiple(of: 2)
      }
      """#
    } expansion: {
      """
      @When(true)
      func isSelected(frameID: Int) -> Bool {
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func isSelected(frameID: Int) -> Bool",
          parameters: [
            "frameID": frameID
          ]
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _isSelected(frameID: Int) -> Bool {
          return frameID.isMultiple(of: 2)
        }
        let result = _isSelected(frameID: frameID)
        event.result = .success(result)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        if result == true {
          autoLogger.emitIfEnabled(event: event, runtime: runtime)
        }
        return result
      }
      """
    }
  }

  @Test
  func optionalIntFunction_withWhenTrait_emitsOnlyMatchingSuccessValue() throws {
    assertMacro {
      #"""
      @When(Optional.some(42))
      @Log
      func selectedValue(flag: Bool) -> Int? {
        return flag ? 42 : nil
      }
      """#
    } expansion: {
      """
      @When(Optional.some(42))
      func selectedValue(flag: Bool) -> Int? {
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func selectedValue(flag: Bool) -> Int?",
          parameters: [
            "flag": flag
          ]
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _selectedValue(flag: Bool) -> Int? {
          return flag ? 42 : nil
        }
        let result = _selectedValue(flag: flag)
        event.result = .success(AutoLogMetadata.box(result))
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        if result == Optional.some(42) {
          autoLogger.emitIfEnabled(event: event, runtime: runtime)
        }
        return result
      }
      """
    }
  }

  @Test
  func customEquatableFunction_withWhenTrait_emitsOnlyMatchingSuccessValue() throws {
    assertMacro {
      #"""
      @When(SelectionState(isSelected: true))
      @Log
      func selectionState(frameID: Int) -> SelectionState {
        return SelectionState(isSelected: frameID.isMultiple(of: 2))
      }
      """#
    } expansion: {
      """
      @When(SelectionState(isSelected: true))
      func selectionState(frameID: Int) -> SelectionState {
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func selectionState(frameID: Int) -> SelectionState",
          parameters: [
            "frameID": frameID
          ]
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _selectionState(frameID: Int) -> SelectionState {
          return SelectionState(isSelected: frameID.isMultiple(of: 2))
        }
        let result = _selectionState(frameID: frameID)
        event.result = .success(result)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        if result == SelectionState(isSelected: true) {
          autoLogger.emitIfEnabled(event: event, runtime: runtime)
        }
        return result
      }
      """
    }
  }

  @Test
  func function_withBareOmit_skipsExplicitLogInstrumentation() throws {
    assertMacro {
      """
      @Omit
      @Log
      func hidden() {
        print("hidden")
      }
      """
    } expansion: {
      """
      @Omit
      func hidden() {
        print("hidden")
      }
      """
    }
  }

  @Test
  func boolFunction_withConditionalOmitResult_buildsOmissionRule() throws {
    assertMacro {
      #"""
      @Omit(.result, containing: "false")
      @Log
      func isSelected(flag: Bool) -> Bool {
        return flag
      }
      """#
    } expansion: {
      """
      @Omit(.result, containing: "false")
      func isSelected(flag: Bool) -> Bool {
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func isSelected(flag: Bool) -> Bool",
          parameters: [
            "flag": flag
          ],
          omissionRules: [AutoLogOmissionRule(scope: AutoLogOmissionRule.Scope.result, tokens: ["false"])]
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _isSelected(flag: Bool) -> Bool {
          return flag
        }
        let result = _isSelected(flag: flag)
        event.result = .success(result)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
        return result
      }
      """
    }
  }

  @Test
  func throwingFunction_withConditionalErrorOmitAndCount_buildsOmissionRule() throws {
    assertMacro {
      #"""
      @Omit(.error, upToCount: 1)
      @Log
      func refreshSession() throws {
        throw AuthError.expired
      }
      """#
    } expansion: {
      """
      @Omit(.error, upToCount: 1)
      func refreshSession() throws {
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func refreshSession() throws",
          omissionRules: [AutoLogOmissionRule(scope: AutoLogOmissionRule.Scope.error, tokens: [], upToCount: 1)]
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _refreshSession() throws {
          throw AuthError.expired
        }
        do {
          let _ = try _refreshSession()
          if let __logStart {
            event.duration = ContinuousClock.now - __logStart
          }
          autoLogger.emitIfEnabled(event: event, runtime: runtime)
        } catch {
          event.result = .failure(error)
          if let __logStart {
            event.duration = ContinuousClock.now - __logStart
          }
          autoLogger.emitIfEnabled(event: event, runtime: runtime)
          throw error
        }
      }
      """
    }
  }

  @Test
  func throwingFunction_withConditionalErrorTokensAndOmitResult_stacksRules() throws {
    assertMacro {
      #"""
      @Omit(.result)
      @Omit(.error, containing: ["iamError", "nextAuthStep", "UserName"], upToCount: 1)
      @Log
      func refreshSession() throws -> Bool {
        throw AuthError.expired
      }
      """#
    } expansion: {
      """
      @Omit(.result)
      @Omit(.error, containing: ["iamError", "nextAuthStep", "UserName"], upToCount: 1)
      func refreshSession() throws -> Bool {
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func refreshSession() throws -> Bool",
          omissionRules: [AutoLogOmissionRule(scope: AutoLogOmissionRule.Scope.error, tokens: ["iamError", "nextAuthStep", "UserName"], upToCount: 1)]
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _refreshSession() throws -> Bool {
          throw AuthError.expired
        }
        do {
          let result = try _refreshSession()
          if let __logStart {
            event.duration = ContinuousClock.now - __logStart
          }
          autoLogger.emitIfEnabled(event: event, runtime: runtime)
          return result
        } catch {
          event.result = .failure(error)
          if let __logStart {
            event.duration = ContinuousClock.now - __logStart
          }
          autoLogger.emitIfEnabled(event: event, runtime: runtime)
          throw error
        }
      }
      """
    }
  }

  @Test
  func functionWithHandledCatch_emitsInlineHandledErrorEvent() throws {
    assertMacro {
      #"""
      @Log
      func project() {
        do {
          try performMirrorProjection()
        } catch {
          projectionStatus = "Error: \(error.localizedDescription)"
        }
      }
      """#
    } expansion: {
      """
      func project() {
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func project()"
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _project() {
          do {
            try performMirrorProjection()
          } catch {
            event.recordHandledError()
            autoLogger.emitHandledErrorIfEnabled(error: error, from: event, runtime: runtime)
                projectionStatus = "Error: \\(error.localizedDescription)"
          }
        }
        let _ = _project()
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
      }
      """
    }
  }

  @Test
  func functionWithExplicitCatchBinding_emitsHandledErrorWithBoundError() throws {
    assertMacro {
      #"""
      @Log
      func project() {
        do {
          try performMirrorProjection()
        } catch let caught {
          projectionStatus = "Error: \(caught)"
        }
      }
      """#
    } expansion: {
      """
      func project() {
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func project()"
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _project() {
          do {
            try performMirrorProjection()
          } catch let caught {
            event.recordHandledError()
            autoLogger.emitHandledErrorIfEnabled(error: caught, from: event, runtime: runtime)
                projectionStatus = "Error: \\(caught)"
          }
        }
        let _ = _project()
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
      }
      """
    }
  }

  @Test
  func boolFunction_logsGuardEarlyReturn() throws {
    assertMacro {
      #"""
      @Log
      func deleteActiveLayout(collection: LayoutCollection) -> Bool {
        guard collection.layouts.count > 1 else {
          return false
        }

        return true
      }
      """#
    } expansion: {
      """
      func deleteActiveLayout(collection: LayoutCollection) -> Bool {
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func deleteActiveLayout(collection: LayoutCollection) -> Bool",
          parameters: [
            "collection": collection
          ]
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _deleteActiveLayout(collection: LayoutCollection) -> Bool {
          guard collection.layouts.count > 1 else {
            event.earlyExit = AutoLogEarlyExit(kind: AutoLogEarlyExit.Kind.guard, intent: .unknown, condition: "!(collection.layouts.count > 1)", message: nil)
            return false
          }

          return true
        }
        let result = _deleteActiveLayout(collection: collection)
        event.result = .success(result)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
        return result
      }
      """
    }
  }

  @Test
  func boolFunction_logsFailingGuardConditionTerms() throws {
    assertMacro {
      #"""
      @Log
      func removed(status: OSStatus) -> Bool {
        guard status == errSecSuccess || status == errSecItemNotFound else {
          return false
        }

        return true
      }
      """#
    } expansion: {
      """
      func removed(status: OSStatus) -> Bool {
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func removed(status: OSStatus) -> Bool",
          parameters: [
            "status": status
          ]
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _removed(status: OSStatus) -> Bool {
          var __logCondition0 = AutoLogConditionTrace.Evaluator()
          guard __logCondition0.term("status == errSecSuccess", status == errSecSuccess) || __logCondition0.term("status == errSecItemNotFound", status == errSecItemNotFound) else {
            event.earlyExit = AutoLogEarlyExit(kind: AutoLogEarlyExit.Kind.guard, intent: .unknown, condition: AutoLogConditionTrace(expression: "status == errSecSuccess || status == errSecItemNotFound", passed: false, terms: __logCondition0.terms).failingDescription ?? "!(status == errSecSuccess || status == errSecItemNotFound)", message: nil)
            return false
            }

            return true
        }
        let result = _removed(status: status)
        event.result = .success(result)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
        return result
      }
      """
    }
  }

  @Test
  func voidFunction_logsGuardBareReturn() throws {
    assertMacro {
      #"""
      @Log
      func refresh(sessionToken: String?) {
        guard let sessionToken else {
          return
        }

        print(sessionToken)
      }
      """#
    } expansion: {
      """
      func refresh(sessionToken: String?) {
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func refresh(sessionToken: String?)",
          parameters: [
            "sessionToken": AutoLogMetadata.box(sessionToken)
          ]
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _refresh(sessionToken: String?) {
          guard let sessionToken else {
            event.earlyExit = AutoLogEarlyExit(kind: AutoLogEarlyExit.Kind.guard, intent: .unknown, condition: "!(let sessionToken)", message: nil)
            return
          }

          print(sessionToken)
        }
        let _ = _refresh(sessionToken: sessionToken)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
      }
      """
    }
  }

  @Test
  func boolFunction_logsIfBranchEarlyReturn() throws {
    assertMacro {
      #"""
      @Log
      func deleteActiveLayout(collection: LayoutCollection) -> Bool {
        if collection.layouts.isEmpty {
          return false
        }

        return true
      }
      """#
    } expansion: {
      """
      func deleteActiveLayout(collection: LayoutCollection) -> Bool {
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func deleteActiveLayout(collection: LayoutCollection) -> Bool",
          parameters: [
            "collection": collection
          ]
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _deleteActiveLayout(collection: LayoutCollection) -> Bool {
          if collection.layouts.isEmpty {
            event.recordBranchDecision(kind: AutoLogEarlyExit.Kind.if, condition: "collection.layouts.isEmpty")
            event.earlyExit = AutoLogEarlyExit(kind: AutoLogEarlyExit.Kind.if, intent: .unknown, condition: "collection.layouts.isEmpty", message: nil)
            return false
          }

          return true
        }
        let result = _deleteActiveLayout(collection: collection)
        event.result = .success(result)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
        return result
      }
      """
    }
  }

  @Test
  func stringFunction_logsSwitchEarlyReturns() throws {
    assertMacro {
      #"""
      @Log
      func route(kind: Int) -> String {
        switch kind {
        case 0:
          return "zero"
        default:
          return "other"
        }
      }
      """#
    } expansion: {
      """
      func route(kind: Int) -> String {
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func route(kind: Int) -> String",
          parameters: [
            "kind": kind
          ]
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _route(kind: Int) -> String {
          switch kind {
          case 0:
            event.recordBranchDecision(kind: AutoLogEarlyExit.Kind.switchCase, condition: "switch kind: 0")
            event.earlyExit = AutoLogEarlyExit(kind: AutoLogEarlyExit.Kind.switchCase, intent: .unknown, condition: "switch kind: 0", message: nil)
            return "zero"
          default:
            event.recordBranchDecision(kind: AutoLogEarlyExit.Kind.switchDefault, condition: "switch kind: default")
            event.earlyExit = AutoLogEarlyExit(kind: AutoLogEarlyExit.Kind.switchDefault, intent: .unknown, condition: "switch kind: default", message: nil)
            return "other"
          }
        }
        let result = _route(kind: kind)
        event.result = .success(result)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
        return result
      }
      """
    }
  }

  @Test
  func voidFunction_preservesDeferBlock() throws {
    assertMacro {
      #"""
      @Log
      func cleanup() {
        defer {
          closeHandle()
        }

        openHandle()
      }
      """#
    } expansion: {
      """
      func cleanup() {
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func cleanup()"
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _cleanup() {
          defer {
            closeHandle()
          }

          openHandle()
        }
        let _ = _cleanup()
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
      }
      """
    }
  }

  @Test
  func asyncFunction_preservesForAwaitLoop() throws {
    assertMacro {
      #"""
      @Log
      func consume(stream: AsyncStream<Int>) async {
        for await value in stream {
          print(value)
        }
      }
      """#
    } expansion: {
      """
      func consume(stream: AsyncStream<Int>) async {
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func consume(stream: AsyncStream<Int>) async",
          parameters: [
            "stream": stream
          ]
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _consume(stream: AsyncStream<Int>) async {
          for await value in stream {
            print(value)
          }
        }
        let _ = await _consume(stream: stream)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
      }
      """
    }
  }

  @Test
  func boolFunction_usesExplicitEarlyExitIntentAndMessage() throws {
    assertMacro {
      #"""
      @Log
      func cachedLookup(hit: Bool) -> Bool {
        if hit {
          AutoLog.earlyExit(.optimize, "cache hit")
          return true
        }

        return false
      }
      """#
    } expansion: {
      """
      func cachedLookup(hit: Bool) -> Bool {
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func cachedLookup(hit: Bool) -> Bool",
          parameters: [
            "hit": hit
          ]
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _cachedLookup(hit: Bool) -> Bool {
          if hit {
            event.recordBranchDecision(kind: AutoLogEarlyExit.Kind.if, condition: "hit")
            event.earlyExit = AutoLogEarlyExit(kind: AutoLogEarlyExit.Kind.if, intent: .optimize, condition: "hit", message: "cache hit")
                return true
          }

          return false
        }
        let result = _cachedLookup(hit: hit)
        event.result = .success(result)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
        return result
      }
      """
    }
  }

  @Test
  func boolFunction_usesExplicitEarlyExitIntentWithoutMessage() throws {
    assertMacro {
      #"""
      @Log
      func cachedLookup(hit: Bool) -> Bool {
        if hit {
          AutoLog.earlyExit(.optimize)
          return true
        }

        return false
      }
      """#
    } expansion: {
      """
      func cachedLookup(hit: Bool) -> Bool {
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func cachedLookup(hit: Bool) -> Bool",
          parameters: [
            "hit": hit
          ]
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _cachedLookup(hit: Bool) -> Bool {
          if hit {
            event.recordBranchDecision(kind: AutoLogEarlyExit.Kind.if, condition: "hit")
            event.earlyExit = AutoLogEarlyExit(kind: AutoLogEarlyExit.Kind.if, intent: .optimize, condition: "hit", message: nil)
                return true
          }

          return false
        }
        let result = _cachedLookup(hit: hit)
        event.result = .success(result)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
        return result
      }
      """
    }
  }

  @Test
  func boolFunction_usesExplicitEarlyExitDefaults() throws {
    assertMacro {
      #"""
      @Log
      func deleteActiveLayout(collection: LayoutCollection) -> Bool {
        guard collection.layouts.count > 1 else {
          AutoLog.earlyExit()
          return false
        }

        return true
      }
      """#
    } expansion: {
      """
      func deleteActiveLayout(collection: LayoutCollection) -> Bool {
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func deleteActiveLayout(collection: LayoutCollection) -> Bool",
          parameters: [
            "collection": collection
          ]
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _deleteActiveLayout(collection: LayoutCollection) -> Bool {
          guard collection.layouts.count > 1 else {
            event.earlyExit = AutoLogEarlyExit(kind: AutoLogEarlyExit.Kind.guard, intent: .unknown, condition: "!(collection.layouts.count > 1)", message: "unknown")
                return false
          }

          return true
        }
        let result = _deleteActiveLayout(collection: collection)
        event.result = .success(result)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
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
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = .foo
        var event = AutoLogEvent(
          level: .debug,
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func foo(bar: String) -> String",
          parameters: [
            "bar": bar
          ]
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _foo(bar: String) -> String {
          print("Foo: \(bar)")
        }
        let result = _foo(bar: bar)
        event.result = .success(result)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
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
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func foo(bar: String) -> String",
          parameters: [
            "bar": bar
          ],
          tags: ["example"]
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _foo(bar: String) -> String {
          return "Foo: \(bar)"
        }
        let result = _foo(bar: bar)
        event.result = .success(result)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
        return result
      }
      """#
    }
  }

  @Test
  func voidFunction_recordsNonReturningIfElseBranchPath() throws {
    assertMacro {
      #"""
      @Log
      func toggleFramePicker(isVisible: Bool) {
        if isVisible {
          pickerPanel.hide()
        } else {
          pickerPanel.show()
        }
      }
      """#
    } expansion: {
      """
      func toggleFramePicker(isVisible: Bool) {
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func toggleFramePicker(isVisible: Bool)",
          parameters: [
            "isVisible": isVisible
          ]
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _toggleFramePicker(isVisible: Bool) {
          if isVisible {
            event.recordBranchDecision(kind: AutoLogEarlyExit.Kind.if, condition: "isVisible")
                pickerPanel.hide()
          } else {
            event.recordBranchDecision(kind: AutoLogEarlyExit.Kind.else, condition: "isVisible")
                pickerPanel.show()
          }
        }
        let _ = _toggleFramePicker(isVisible: isVisible)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
      }
      """
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
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func foo(_ bar: String, baz biz: Int) -> (String, Int)",
          parameters: [
            "bar": bar,
            "biz": biz
          ]
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _foo(bar: String, biz: Int) -> (String, Int) {
          return ("Bar: \(bar)", biz * 2)
        }
        let result = _foo(bar: bar, biz: biz)
        event.result = .success(result)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
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
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          level: .debug,
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "mutating func foo()"
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _foo() {
          self.counter += 1
        }
        let _ = _foo()
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
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
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
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
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _foo(bar: String) {
          self.bar = bar
        }
        let _ = _foo(bar: bar)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
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
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "mutating func foo() throws"
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _foo() throws {
          if self.counter == 0 {
            event.recordBranchDecision(kind: AutoLogEarlyExit.Kind.if, condition: "self.counter == 0")
            event.earlyExit = AutoLogEarlyExit(kind: AutoLogEarlyExit.Kind.if, intent: .unknown, condition: "self.counter == 0", message: nil)
            throw NSError(domain: com.foo.test, code: .zero)
          } else {
            event.recordBranchDecision(kind: AutoLogEarlyExit.Kind.else, condition: "self.counter == 0")
                self.counter -= 1
          }
        }
        do {
          let _ = try _foo()
          if let __logStart {
            event.duration = ContinuousClock.now - __logStart
          }
          autoLogger.emitIfEnabled(event: event, runtime: runtime)
        } catch {
          event.result = .failure(error)
          if let __logStart {
            event.duration = ContinuousClock.now - __logStart
          }
          autoLogger.emitIfEnabled(event: event, runtime: runtime)
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
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          level: .error,
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func foo() throws",
          tags: ["example"]
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _foo() throws {
          throw NSError()
        }
        do {
          let _ = try _foo()
          if let __logStart {
            event.duration = ContinuousClock.now - __logStart
          }
          autoLogger.emitIfEnabled(event: event, runtime: runtime)
        } catch {
          event.result = .failure(error)
          if let __logStart {
            event.duration = ContinuousClock.now - __logStart
          }
          autoLogger.emitIfEnabled(event: event, runtime: runtime)
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
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func foo() throws -> Int"
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _foo() throws -> Int {
          if Bool.random() {
            event.recordBranchDecision(kind: AutoLogEarlyExit.Kind.if, condition: "Bool.random()")
            event.earlyExit = AutoLogEarlyExit(kind: AutoLogEarlyExit.Kind.if, intent: .unknown, condition: "Bool.random()", message: nil)
            throw NSError(domain: com.foo.test, code: .zero)
          } else {
            event.recordBranchDecision(kind: AutoLogEarlyExit.Kind.else, condition: "Bool.random()")
            event.earlyExit = AutoLogEarlyExit(kind: AutoLogEarlyExit.Kind.else, intent: .unknown, condition: "!Bool.random()", message: nil)
            return .zero
          }
        }
        do {
          let result = try _foo()
          event.result = .success(result)
          if let __logStart {
            event.duration = ContinuousClock.now - __logStart
          }
          autoLogger.emitIfEnabled(event: event, runtime: runtime)
          return result
        } catch {
          event.result = .failure(error)
          if let __logStart {
            event.duration = ContinuousClock.now - __logStart
          }
          autoLogger.emitIfEnabled(event: event, runtime: runtime)
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
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func foo(_ value: Int) throws"
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _foo(value: Int) throws {
          if Bool.random() {
            event.recordBranchDecision(kind: AutoLogEarlyExit.Kind.if, condition: "Bool.random()")
                print("true")
            event.earlyExit = AutoLogEarlyExit(kind: AutoLogEarlyExit.Kind.if, intent: .unknown, condition: "Bool.random()", message: nil)
            throw NSError(domain: com.foo.test, code: .zero)
          } else {
            event.recordBranchDecision(kind: AutoLogEarlyExit.Kind.else, condition: "Bool.random()")
                print("false")
          }
        }
        do {
          let _ = try _foo(value: value)
          if let __logStart {
            event.duration = ContinuousClock.now - __logStart
          }
          autoLogger.emitIfEnabled(event: event, runtime: runtime)
        } catch {
          event.result = .failure(error)
          if let __logStart {
            event.duration = ContinuousClock.now - __logStart
          }
          autoLogger.emitIfEnabled(event: event, runtime: runtime)
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
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func foo(_ value: Int, content: String) throws -> (Int, String)"
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _foo(value: Int, content: String) throws -> (Int, String) {
          if Bool.random() {
            event.recordBranchDecision(kind: AutoLogEarlyExit.Kind.if, condition: "Bool.random()")
            event.earlyExit = AutoLogEarlyExit(kind: AutoLogEarlyExit.Kind.if, intent: .unknown, condition: "Bool.random()", message: nil)
            throw NSError(domain: com.foo.test, code: .zero)
          } else {
            event.recordBranchDecision(kind: AutoLogEarlyExit.Kind.else, condition: "Bool.random()")
            event.earlyExit = AutoLogEarlyExit(kind: AutoLogEarlyExit.Kind.else, intent: .unknown, condition: "!Bool.random()", message: nil)
            return (value, "\(content): \(value)")
          }
        }
        do {
          let result = try _foo(value: value, content: content)
          event.result = .success(result)
          if let __logStart {
            event.duration = ContinuousClock.now - __logStart
          }
          autoLogger.emitIfEnabled(event: event, runtime: runtime)
          return result
        } catch {
          event.result = .failure(error)
          if let __logStart {
            event.duration = ContinuousClock.now - __logStart
          }
          autoLogger.emitIfEnabled(event: event, runtime: runtime)
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
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          level: "fault",
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func foo() async throws",
          tags: ["example"]
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _foo() async throws {
          try await Task.sleep(nanoseconds: 100_000_000)
        }
        do {
          let _ = try await _foo()
          if let __logStart {
            event.duration = ContinuousClock.now - __logStart
          }
          autoLogger.emitIfEnabled(event: event, runtime: runtime)
        } catch {
          event.result = .failure(error)
          if let __logStart {
            event.duration = ContinuousClock.now - __logStart
          }
          autoLogger.emitIfEnabled(event: event, runtime: runtime)
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
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func performTask(completion: @escaping () -> Void)",
          parameters: [
            "completion": completion
          ]
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _performTask(completion: @escaping () -> Void) {
          completion()
        }
        let _ = _performTask(completion: completion)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
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
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          level: .info,
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func check(condition: @autoclosure () -> Bool) -> Bool",
          parameters: [
            "condition": condition
          ]
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _check(condition: @autoclosure () -> Bool) -> Bool {
          return condition()
        }
        let result = _check(condition: condition())
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
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
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func update(value: inout Int, with newValue: Int)",
          parameters: [
            "value": value,
            "newValue": newValue
          ]
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _update(value: inout Int, newValue: Int) {
          value = newValue
        }
        let _ = _update(value: &value, newValue: newValue)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
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
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "static func staticMethod(info: String) -> String"
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _staticMethod(info: String) -> String {
          return "Static: \(info)"
        }
        let result = _staticMethod(info: info)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
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
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func execute(operation: () throws -> Void) rethrows"
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _execute(operation: () throws -> Void) rethrows {
          try operation()
        }
        do {
          let _ = try _execute(operation: operation)
          if let __logStart {
            event.duration = ContinuousClock.now - __logStart
          }
          autoLogger.emitIfEnabled(event: event, runtime: runtime)
        } catch {
          event.result = .failure(error)
          if let __logStart {
            event.duration = ContinuousClock.now - __logStart
          }
          autoLogger.emitIfEnabled(event: event, runtime: runtime)
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
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = .custom
        var event = AutoLogEvent(
          level: .debug,
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func transform(value: Int, using transform: (Int) -> String) -> String",
          tags: [.commonTag, "example"]
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _transform(value: Int, transform: (Int) -> String) -> String {
          return transform(value)
        }
        let result = _transform(value: value, transform: transform)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
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
      @Log
      func ping() {}
      """#
    } expansion: {
      """
      @Tag("example")
      @Tag(.commonTag)
      func ping() {
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func ping()",
          tags: ["example", .commonTag]
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _ping() {
        }
        let _ = _ping()
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
      }
      """
    }
  }

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
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
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
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _combine(first: T, second: U) -> (T, U) {
          return (first, second)
        }
        let result = _combine(first: first, second: second)
        event.result = .success(result)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
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
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: #"func greet(name: String = "Guest") -> String"#,
          parameters: [
            "name": name
          ]
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _greet(name: String) -> String {
          return "Hello, \(name)!"
        }
        let result = _greet(name: name)
        event.result = .success(result)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
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
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func sum(numbers: Int...) -> Int",
          parameters: [
            "numbers": numbers
          ]
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _sum(numbers: Int...) -> Int {
          return numbers.reduce(0, +)
        }
        let result = _sum(numbers: numbers)
        event.result = .success(result)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
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
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func compute(value: Int) -> Int",
          parameters: [
            "value": value
          ]
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _compute(value: Int) -> Int {
          return value * value
        }
        let result = _compute(value: value)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
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
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func makeIncrementer() -> (Int) -> Int"
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _makeIncrementer() -> (Int) -> Int {
          return {
            $0 + 1
          }
        }
        let result = _makeIncrementer()
        event.result = .success(result)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
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
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func fetchData(completion: @escaping () async -> String)",
          parameters: [
            "completion": completion
          ]
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _fetchData(completion: @escaping () async -> String) {
          Task {
            let data = await completion()
            print(data)
          }
        }
        let _ = _fetchData(completion: completion)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
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
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func updateUI(message: String)",
          parameters: [
            "message": message
          ]
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _updateUI(message: String) {
          print(message)
        }
        let _ = _updateUI(message: message)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
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
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func process<T: Equatable, U: Numeric>(first: T, second: U) -> Bool",
          parameters: [
            "first": first,
            "second": second
          ]
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _process(first: T, second: U) -> Bool {
          return true
        }
        let result = _process(first: first, second: second)
        event.result = .success(result)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
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
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func performAction()"
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _performAction() {
          print("Action performed")
        }
        let _ = _performAction()
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
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
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func getOptionalValue() -> Int?"
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _getOptionalValue() -> Int? {
          return nil
        }
        let result = _getOptionalValue()
        event.result = .success(AutoLogMetadata.box(result))
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
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
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func performAsyncTask(completion: @escaping () async throws -> String) async throws -> String",
          parameters: [
            "completion": completion
          ]
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _performAsyncTask(completion: @escaping () async throws -> String) async throws -> String {
          return try await completion()
        }
        do {
          let result = try await _performAsyncTask(completion: completion)
          event.result = .success(result)
          if let __logStart {
            event.duration = ContinuousClock.now - __logStart
          }
          autoLogger.emitIfEnabled(event: event, runtime: runtime)
          return result
        } catch {
          event.result = .failure(error)
          if let __logStart {
            event.duration = ContinuousClock.now - __logStart
          }
          autoLogger.emitIfEnabled(event: event, runtime: runtime)
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
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "override func description() -> String"
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _description() -> String {
          return "Override"
        }
        let result = _description()
        event.result = .success(result)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
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
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func updateScore(score: inout Int, increment: Int = 1)",
          parameters: [
            "score": score,
            "increment": increment
          ]
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _updateScore(score: inout Int, increment: Int) {
          score += increment
        }
        let _ = _updateScore(score: &score, increment: increment)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
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
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func optionalTest(value: String?) -> String",
          parameters: [
            "value": AutoLogMetadata.box(value)
          ]
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _optionalTest(value: String?) -> String {
          return value ?? "Default"
        }
        let result = _optionalTest(value: value)
        event.result = .success(result)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
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
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func merge<T, U>(_ first: [T], with second: [U]) -> [(T, U)]\n  where T: Comparable, U: Comparable",
          parameters: [
            "first": first
          ]
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _merge(first: [T], second: [U]) -> [(T, U)]
        {
          return []
        }
        let result = _merge(first: first, second: second)
        event.result = .success(result)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
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
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func perform(action: (() -> Void)? = nil)",
          parameters: [
            "action": AutoLogMetadata.box(action)
          ]
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _perform(action: (() -> Void)?) {
          action?()
        }
        let _ = _perform(action: action)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
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
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "static func create<T>(value: T) -> [T]",
          parameters: [
            "value": value
          ]
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _create(value: T) -> [T] {
          return [value]
        }
        let result = _create(value: value)
        event.result = .success(result)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
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
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func process(pair: (Int, String)) -> String",
          parameters: [
            "pair": pair
          ]
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _process(pair: (Int, String)) -> String {
          return "\(pair.0) - \(pair.1)"
        }
        let result = _process(pair: pair)
        event.result = .success(result)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
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
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func filterElements<T>(elements: [T], using predicate: (T) -> Bool) -> [T]",
          parameters: [
            "elements": elements,
            "predicate": predicate
          ]
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _filterElements(elements: [T], predicate: (T) -> Bool) -> [T] {
          return elements.filter(predicate)
        }
        let result = _filterElements(elements: elements, predicate: predicate)
        event.result = .success(result)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
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
        let runtime = AutoLog.runtimeSnapshot()
        let autoLogger: any AutoLogger = runtime.logger
        var event = AutoLogEvent(
          source: AutoLogSource.current,

          location: "TestModule/Test.swift:1:1",
          declaration: "func filterElements<T>(elements: [T], using predicate: (T) -> Bool) -> [T]",
          parameters: [
            "elements": elements,
            "predicate": predicate
          ]
        )
        autoLogger.emitStart(event: event, runtime: runtime)
        let __logStart = autoLogger.shouldMeasureTiming(for: event, runtime: runtime) ? ContinuousClock.now : nil
        func _filterElements(elements: [T], predicate: (T) -> Bool) -> [T] {
          return elements.filter(predicate)
        }
        let result = _filterElements(elements: elements, predicate: predicate)
        event.result = .success(result)
        if let __logStart {
          event.duration = ContinuousClock.now - __logStart
        }
        autoLogger.emitIfEnabled(event: event, runtime: runtime)
        return result
      }
      """
    }
  }

}
