import AutoLogMacro
import MacroTesting
import Testing

@Suite(
  .macros(
    [LoggedMacro.self],
    indentationWidth: .spaces(2),
    record: .missing
  )
)
struct LoggedMacroTests {
  @Test
  func struct_default_noAdditionalAnnotations() throws {
    assertMacro {
      #"""
      @Logged
      struct Foo {
        func bar<T>(_ value: T) -> T {
          return value
        }

        func quaz() -> (Int) -> Int {
          return { $0 + 1 }
        }

        static func quuaz(completion: @escaping () async -> String) {
          Task {
            let data = await completion()
            print(data)
          }
        }
      }
      """#
    } expansion: {
      """
      struct Foo {
        @Log
        func bar<T>(_ value: T) -> T {
          return value
        }
        @Log

        func quaz() -> (Int) -> Int {
          return { $0 + 1 }
        }
        @Log

        static func quuaz(completion: @escaping () async -> String) {
          Task {
            let data = await completion()
            print(data)
          }
        }
      }
      """
    }
  }

  @Test
  func class_withAutoLoggerAsStaticParameter_noAdditionalAnnotations() throws {
    assertMacro {
      #"""
      @Logged(using: .custom)
      class Foo {
        func bar<T>(_ value: T) -> T {
          return value
        }

        func quaz() -> (Int) -> Int {
          return { $0 + 1 }
        }

        static func quuaz(completion: @escaping () async -> String) {
          Task {
            let data = await completion()
            print(data)
          }
        }
      }
      """#
    } expansion: {
      """
      class Foo {
        @Log(using: .custom)
        func bar<T>(_ value: T) -> T {
          return value
        }
        @Log(using: .custom)

        func quaz() -> (Int) -> Int {
          return { $0 + 1 }
        }
        @Log(using: .custom)

        static func quuaz(completion: @escaping () async -> String) {
          Task {
            let data = await completion()
            print(data)
          }
        }
      }
      """
    }
  }

  @Test
  func struct_emitSingleFailures_preservesCompileTimeEmissionArgument() throws {
    assertMacro {
      #"""
      @Logged(emit: .failures)
      struct Foo {
        func bar() {
          print("bar")
        }
      }
      """#
    } expansion: {
      """
      struct Foo {
        @Log(emit: .failures)
        func bar() {
          print("bar")
        }
      }
      """
    }
  }

  @Test
  func struct_emitSingleFailuresAndMeasureFalse_preservesCompileTimeArguments() throws {
    assertMacro {
      #"""
      @Logged(emit: .failures, measure: false)
      struct Foo {
        func bar() {
          print("bar")
        }
      }
      """#
    } expansion: {
      """
      struct Foo {
        @Log(emit: .failures, measure: false)
        func bar() {
          print("bar")
        }
      }
      """
    }
  }

  @Test
  func struct_emitTypedFailuresAndWarnings_preservesCompileTimeEmissionArgument() throws {
    assertMacro {
      #"""
      @Logged(emit: [.failures, .warnings])
      struct Foo {
        func bar() {
          print("bar")
        }
      }
      """#
    } expansion: {
      """
      struct Foo {
        @Log(emit: [.failures, .warnings])
        func bar() {
          print("bar")
        }
      }
      """
    }
  }

  @Test
  func class_withAutoLoggerAsInitializer_noAdditionalAnnotations() throws {
    assertMacro {
      #"""
      @Logged(using: Custom())
      class Foo {
        func bar<T>(_ value: T) -> T {
          return value
        }

        func quaz() -> (Int) -> Int {
          return { $0 + 1 }
        }

        static func quuaz(completion: @escaping () async -> String) {
          Task {
            let data = await completion()
            print(data)
          }
        }
      }
      """#
    } expansion: {
      """
      class Foo {
        @Log(using: Custom())
        func bar<T>(_ value: T) -> T {
          return value
        }
        @Log(using: Custom())

        func quaz() -> (Int) -> Int {
          return { $0 + 1 }
        }
        @Log(using: Custom())

        static func quuaz(completion: @escaping () async -> String) {
          Task {
            let data = await completion()
            print(data)
          }
        }
      }
      """
    }
  }

  @Test
  func class_withAutoLoggerAsFunction_noAdditionalAnnotations() throws {
    assertMacro {
      #"""
      @Logged(using: .custom(module: "Foo"))
      class Foo {
        func bar<T>(_ value: T) -> T {
          return value
        }

        func quaz() -> (Int) -> Int {
          return { $0 + 1 }
        }

        static func quuaz(completion: @escaping () async -> String) {
          Task {
            let data = await completion()
            print(data)
          }
        }
      }
      """#
    } expansion: {
      """
      class Foo {
        @Log(using: .custom(module: "Foo"))
        func bar<T>(_ value: T) -> T {
          return value
        }
        @Log(using: .custom(module: "Foo"))

        func quaz() -> (Int) -> Int {
          return { $0 + 1 }
        }
        @Log(using: .custom(module: "Foo"))

        static func quuaz(completion: @escaping () async -> String) {
          Task {
            let data = await completion()
            print(data)
          }
        }
      }
      """
    }
  }

  @Test
  func finalClass_withoutMembers_doesNotEmitCompanionExtension() throws {
    assertMacro {
      """
      @Logged
      final class Foo {}
      """
    } expansion: {
      """
      final class Foo {}
      """
    }
  }

  @Test
  func actor_default_withOmmitAnnotations() throws {
    assertMacro {
      #"""
      @Logged
      actor Foo {
        @Omit(.parameters)
        func bar<T>(_ value: T) -> T {
          return value
        }

        @Omit
        func quaz() -> (Int) -> Int {
          return { $0 + 1 }
        }

        @Omit(.result)
        static func quuaz(completion: @escaping () async -> String) {
          Task {
            let data = await completion()
            print(data)
          }
        }
      }
      """#
    } expansion: {
      """
      actor Foo {
        @Omit(.parameters)
        @Log
        func bar<T>(_ value: T) -> T {
          return value
        }

        @Omit
        func quaz() -> (Int) -> Int {
          return { $0 + 1 }
        }

        @Omit(.result)
        @Log
        static func quuaz(completion: @escaping () async -> String) {
          Task {
            let data = await completion()
            print(data)
          }
        }
      }
      """
    }
  }

  @Test
  func enum_default_noAdditionalAnnotations() throws {
    assertMacro {
      #"""
      @Logged
      enum Foo {
        case bar(Bar)
        case quaz
        case quuaz

        static func _bar() -> Foo { 
          Foo.bar(.example)
        }
      }
      """#
    } expansion: {
      """
      enum Foo {
        case bar(Bar)
        case quaz
        case quuaz
        @Log

        static func _bar() -> Foo { 
          Foo.bar(.example)
        }
      }
      """
    }
  }

  @Test
  func extension_default_noAdditionalAnnotations() throws {
    assertMacro {
      #"""
      @Logged
      extension Foo {
        mutating func bar() -> Self {
          self.bar = .example
          return self
        }

        static func quaz(quuaz: Quuaz) -> Self { 
          Self(bar: nil, quuaz: quaaz)
        }
      }
      """#
    } expansion: {
      """
      extension Foo {
        @Log
        mutating func bar() -> Self {
          self.bar = .example
          return self
        }
        @Log

        static func quaz(quuaz: Quuaz) -> Self { 
          Self(bar: nil, quuaz: quaaz)
        }
      }
      """
    }
  }

  @Test
  func privateNestedStruct_doesNotEmitCompanionExtension() throws {
    assertMacro {
      #"""
      actor ErrorReporter {
        @Logged
        private struct ReportedError: Error {
          let code: String

          func reportCode() -> String {
            code
          }
        }
      }
      """#
    } expansion: {
      """
      actor ErrorReporter {
        private struct ReportedError: Error {
          let code: String
          @Log

          func reportCode() -> String {
            code
          }
        }
      }
      """
    }
  }

  @Test
  func fileprivateStruct_doesNotEmitCompanionExtension() throws {
    assertMacro {
      #"""
      @Logged
      fileprivate struct ChallengeBody: Encodable {
        let challenge: String

        func encodedChallenge() -> String {
          challenge
        }
      }
      """#
    } expansion: {
      """
      fileprivate struct ChallengeBody: Encodable {
        let challenge: String
        @Log

        func encodedChallenge() -> String {
          challenge
        }
      }
      """
    }
  }

  @Test
  func viewRepresentable_skipsFrameworkLifecycleMethods() throws {
    assertMacro {
      #"""
      @Logged
      struct RegistrationWebView: UIViewRepresentable {
        func makeUIView(context: Context) -> WKWebView {
          WKWebView()
        }

        func updateUIView(_ uiView: WKWebView, context: Context) {
          uiView.stopLoading()
        }

        func userStartedRegistration() {
          print("started")
        }
      }
      """#
    } expansion: {
      """
      struct RegistrationWebView: UIViewRepresentable {
        func makeUIView(context: Context) -> WKWebView {
          WKWebView()
        }

        func updateUIView(_ uiView: WKWebView, context: Context) {
          uiView.stopLoading()
        }
        @Log

        func userStartedRegistration() {
          print("started")
        }
      }
      """
    }
  }

  @Test
  func webKitDelegate_skipsDelegateCallbacksWithIUOParameters() throws {
    assertMacro {
      #"""
      @Logged
      class Coordinator: NSObject, WKNavigationDelegate {
        func webView(
          _ webView: WKWebView,
          didFail navigation: WKNavigation!,
          withError error: Error
        ) {
          webView.stopLoading()
        }

        func userRequestedReload() {
          print("reload")
        }
      }
      """#
    } expansion: {
      """
      class Coordinator: NSObject, WKNavigationDelegate {
        func webView(
          _ webView: WKWebView,
          didFail navigation: WKNavigation!,
          withError error: Error
        ) {
          webView.stopLoading()
        }
        @Log

        func userRequestedReload() {
          print("reload")
        }
      }
      """
    }
  }

  @Test
  func struct_getOnlyComputedProperty_isNotAutoLogged() throws {
    assertMacro {
      #"""
      @Logged
      struct Foo {
        var isCreating: Bool {
          dragState?.mode == .create
        }
      }
      """#
    } expansion: {
      """
      struct Foo {
        var isCreating: Bool {
          dragState?.mode == .create
        }
      }
      """
    }
  }

  @Test
  func struct_getOnlyComputedProperty_withOmitAnnotation() throws {
    assertMacro {
      #"""
      @Logged
      struct Foo {
        @Omit
        var isCreating: Bool {
          dragState?.mode == .create
        }
      }
      """#
    } expansion: {
      """
      struct Foo {
        @Omit
        var isCreating: Bool {
          dragState?.mode == .create
        }
      }
      """
    }
  }
}
