#if canImport(OSLog)
@_exported public import OSLog
#endif
#if canImport(Foundation)
@_exported public import class Foundation.Bundle
#endif

@freestanding(
  declaration,
  names: named(logger)
)
public macro osLogger(
  subsystem: String? = nil,
  category: String? = nil
) = #externalMacro(
  module: "AutoLogMacro",
  type: "OSLoggerMacro"
)

/// Introduce static instance of Logger object and OSLogger protocol conformance
/// to attached declaration.
///
/// - Parameters:
///   - level: Acess level of Logger instance. Defaults to acess level of attached declaration.
///   - subsystem: A Logger sybsystem to which logs are associated with.
///   - category: The Logger category which logs are associated with.
///
/// - Note: ``OSLogged()`` and ``OSLog(level:omit:tag:)`` depends on this macro.
///
/// This macro is specialized to accomodate Logger usage allowing to override its subsystem, category
/// and access level. Once introduced static instance can be access within declaration as
/// well as is visible for ``OSLogged()`` and ``OSLog(level:omit:tag:)`` macro.
///
/// ```swift
/// @MainActor
/// @OSLogger
/// @Observable
/// public class FooModel {
///   func bar() throws -> Bool {
///     self.logger.info("\(#function)")
///     return Bool.random()
///   }
/// }
/// ```
@attached(
  extension,
  names: named(logger),
  conformances: OSLogger
)
public macro OSLogger(
  access level: AccessLevelModifier? = nil,
  subsystem: String? = nil,
  category: String? = nil
) = #externalMacro(
  module: "AutoLogMacro",
  type: "OSLoggerMacro"
)

/// Adds ``OSLog(level:omit:tag:)`` macro to all methods within
/// attached declaration. Declaration must confrom to ``OSLogger`` protocol.
///
/// ```swift
/// @OSLogger
/// @OSLogged
/// struct Foo {
///   // ...
/// }
/// ```
///
/// or manualy add conformance to ``OSLogger`` by
/// ```swift
/// @OSLogged
/// struct Bar: OSLogger {
///   static let logger = OSLogger()
///   // ...
/// }
/// ```
@attached(memberAttribute)
public macro OSLogged() = #externalMacro(
  module: "AutoLogMacro",
  type: "OSLoggedMacro"
)

/// Logs annotated function to Logger instance.
/// Requires conformance to ``OSLogger`` from declaration.
///
/// - Parameters:
///   - level: The logging level to associate with a log.
///   - omit: An infomation that can be omitted upon function capturing.
///   - tag: The tags that can be associated with an event for further processing.
///
/// - Warning: Requires that declaration to which is attached conforms to ``OSLogger``.
@attached(body)
public macro OSLog(
  level: (any Levelable)? = nil,
  omit: any Omittable... = [],
  tag: any Taggable... = []
) = #externalMacro(
  module: "AutoLogMacro",
  type: "OSLogMacro"
)

/// Introduces ``Log(using:)`` to all methods within attached context.
///
/// - Parameter logger: The type that handles captured events.
///
/// Annotating declaration with ``AutoLog(using:)`` will intoduce
/// ``Log(using:)`` macros implicitly to all methods within.
///
/// When  `logger` parameter is specified, introdcued``Log(using:)``
/// macros will use it. In order to override implicit parameter, we must explicity
/// mark a method with ``Log(using:)``
/// ```swift
/// @AutoLog
/// struct Foo {
///   @Log(using: .nsLog)
///   func bar() async throws {
///     // ...
///   }
///
///   func baz() async -> Qux {
///     // ...
///   }
/// }
/// ```
///
/// To omit methods from being anottated, mark method with ``Omit()``
/// ```swift
/// @AutoLog
/// enum Foo {
///   static func bar() -> Bool {
///     // Event will be captured upon execution.
///   }
///
///   @Omit
///   static func baz() throws {
///     // Event won't be captured.
///   }
/// }
/// ```
@attached(memberAttribute)
public macro AutoLog() = #externalMacro(
  module: "AutoLogMacro",
  type: "LoggedMacro"
)

/// Introduces ``Log(emit:level:omit:tag:measure:)`` to all methods in the
/// attached declaration using a compile-time emission policy.
///
/// Supported values are `"all"`, `"completionsOnly"`, `"successesOnly"`, and
/// `"failuresOnly"`. For granular pruning, prefer the typed-array overload:
/// `@AutoLog(emit: [.failures, .warnings])`.
@attached(memberAttribute)
public macro AutoLog(emit emission: String) = #externalMacro(
  module: "AutoLogMacro",
  type: "LoggedMacro"
)

/// Introduces ``Log(emit:level:omit:tag:measure:)`` to all methods in the
/// attached declaration using a typed compile-time emission policy.
///
/// Example: `@AutoLog(emit: [.failures, .warnings])`.
@attached(memberAttribute)
public macro AutoLog(emit emissions: [AutoLogEmission]) = #externalMacro(
  module: "AutoLogMacro",
  type: "LoggedMacro"
)

@attached(memberAttribute)
public macro AutoLog(using logger: any AutoLogger) = #externalMacro(
  module: "AutoLogMacro",
  type: "LoggedMacro"
)

@attached(memberAttribute)
public macro AutoLog(
  using logger: any AutoLogger,
  emit emission: String
) = #externalMacro(
  module: "AutoLogMacro",
  type: "LoggedMacro"
)

@attached(memberAttribute)
public macro AutoLog(
  using logger: any AutoLogger,
  emit emissions: [AutoLogEmission]
) = #externalMacro(
  module: "AutoLogMacro",
  type: "LoggedMacro"
)

@attached(memberAttribute)
public macro AutoLog(architecture logger: any AutoLogger) = #externalMacro(
  module: "AutoLogMacro",
  type: "LoggedMacro"
)

@attached(memberAttribute)
public macro AutoLog(
  architecture logger: any AutoLogger,
  emit emission: String
) = #externalMacro(
  module: "AutoLogMacro",
  type: "LoggedMacro"
)

@attached(memberAttribute)
public macro AutoLog(
  architecture logger: any AutoLogger,
  emit emissions: [AutoLogEmission]
) = #externalMacro(
  module: "AutoLogMacro",
  type: "LoggedMacro"
)

/// Overload for concrete `AutoLogLogger` to avoid existential boxing in
/// macro argument type-checking on Swift 6.2.x.
@attached(memberAttribute)
public macro AutoLog(using logger: AutoLogLogger) = #externalMacro(
  module: "AutoLogMacro",
  type: "LoggedMacro"
)

@attached(memberAttribute)
public macro AutoLog(
  using logger: AutoLogLogger,
  emit emission: String
) = #externalMacro(
  module: "AutoLogMacro",
  type: "LoggedMacro"
)

@attached(memberAttribute)
public macro AutoLog(
  using logger: AutoLogLogger,
  emit emissions: [AutoLogEmission]
) = #externalMacro(
  module: "AutoLogMacro",
  type: "LoggedMacro"
)

@attached(memberAttribute)
public macro AutoLog(architecture logger: AutoLogLogger) = #externalMacro(
  module: "AutoLogMacro",
  type: "LoggedMacro"
)

@attached(memberAttribute)
public macro AutoLog(
  architecture logger: AutoLogLogger,
  emit emission: String
) = #externalMacro(
  module: "AutoLogMacro",
  type: "LoggedMacro"
)

@attached(memberAttribute)
public macro AutoLog(
  architecture logger: AutoLogLogger,
  emit emissions: [AutoLogEmission]
) = #externalMacro(
  module: "AutoLogMacro",
  type: "LoggedMacro"
)

/// Logs annotated function and send captured event to a ``AutoLogger`` instance.
///
/// - Parameter logger: The type that handles captured events.
@attached(body)
public macro Log() = #externalMacro(
  module: "AutoLogMacro",
  type: "LogMacro"
)

@attached(body)
public macro Log(
  level: (any Levelable)? = nil,
  omit: any Omittable... = [],
  tag: any Taggable... = []
) = #externalMacro(
  module: "AutoLogMacro",
  type: "LogMacro"
)

/// Logs only the event paths selected at compile time.
///
/// Runtime ``AutoLogConfiguration`` output filters still control what is
/// printed or routed after an event exists. `emit:` is different: the macro
/// skips code generation for event paths that can never be emitted. Supported
/// values are `"all"`, `"completionsOnly"`, `"successesOnly"`, and
/// `"failuresOnly"`. For granular pruning, prefer the typed-array overload:
/// `@Log(emit: [.failures, .warnings])`.
@attached(body)
public macro Log(
  emit emission: String,
  level: (any Levelable)? = nil,
  omit: any Omittable... = [],
  tag: any Taggable... = [],
  measure: Bool? = nil
) = #externalMacro(
  module: "AutoLogMacro",
  type: "LogMacro"
)

/// Logs only the typed event paths selected at compile time.
@attached(body)
public macro Log(
  emit emissions: [AutoLogEmission],
  level: (any Levelable)? = nil,
  omit: any Omittable... = [],
  tag: any Taggable... = [],
  measure: Bool? = nil
) = #externalMacro(
  module: "AutoLogMacro",
  type: "LogMacro"
)

/// Suppresses repeated identical events within the supplied time window.
///
/// Apply this before `@Log` or within an `@AutoLog` type to quiet chatty call
/// sites such as hover probes or selection polling.
///
/// ```swift
/// @AutoLog
/// struct InteractionManager {
///   @Deduplicate(.seconds(1))
///   func hover(frame: Frame) {
///     // ...
///   }
/// }
/// ```
@attached(body)
public macro Deduplicate(
  _ window: AutoLogDeduplication
) = #externalMacro(
  module: "AutoLogMacro",
  type: "DeduplicateMacro"
)

/// Emits a success event only when the function returns the supplied value.
///
/// Thrown errors still emit as usual, so this is best used for chatty boolean
/// probes where only the `true` case matters.
///
/// ```swift
/// @AutoLog
/// struct InteractionManager {
///   @When(true)
///   func isSelected(frame: Frame) -> Bool {
///     selectedFrameIDs.contains(frame.id)
///   }
/// }
/// ```
@attached(body)
public macro When<T: Equatable>(
  _ expectedResult: T
) = #externalMacro(
  module: "AutoLogMacro",
  type: "WhenMacro"
)


/// Overload that allows controlling performance timing at the function level.
///
/// - Parameter measure: `true` forces timing display even when the global setting is off;
///   `false` suppresses timing code entirely for this function.
@attached(body)
public macro Log(
  measure: Bool
) = #externalMacro(
  module: "AutoLogMacro",
  type: "LogMacro"
)

@attached(body)
public macro Log(
  level: (any Levelable)? = nil,
  omit: any Omittable... = [],
  tag: any Taggable... = [],
  measure: Bool
) = #externalMacro(
  module: "AutoLogMacro",
  type: "LogMacro"
)

@attached(body)
public macro Log(using logger: any AutoLogger) = #externalMacro(
  module: "AutoLogMacro",
  type: "LogMacro"
)

@attached(body)
public macro Log(
  using logger: any AutoLogger,
  emit emission: String,
  level: (any Levelable)? = nil,
  omit: any Omittable... = [],
  tag: any Taggable... = [],
  measure: Bool? = nil
) = #externalMacro(
  module: "AutoLogMacro",
  type: "LogMacro"
)

@attached(body)
public macro Log(
  using logger: any AutoLogger,
  emit emissions: [AutoLogEmission],
  level: (any Levelable)? = nil,
  omit: any Omittable... = [],
  tag: any Taggable... = [],
  measure: Bool? = nil
) = #externalMacro(
  module: "AutoLogMacro",
  type: "LogMacro"
)

@attached(body)
public macro Log(architecture logger: any AutoLogger) = #externalMacro(
  module: "AutoLogMacro",
  type: "LogMacro"
)

@attached(body)
public macro Log(
  architecture logger: any AutoLogger,
  emit emission: String,
  level: (any Levelable)? = nil,
  omit: any Omittable... = [],
  tag: any Taggable... = [],
  measure: Bool? = nil
) = #externalMacro(
  module: "AutoLogMacro",
  type: "LogMacro"
)

@attached(body)
public macro Log(
  architecture logger: any AutoLogger,
  emit emissions: [AutoLogEmission],
  level: (any Levelable)? = nil,
  omit: any Omittable... = [],
  tag: any Taggable... = [],
  measure: Bool? = nil
) = #externalMacro(
  module: "AutoLogMacro",
  type: "LogMacro"
)

/// Overload for concrete `AutoLogLogger` to avoid existential boxing in
/// macro argument type-checking on Swift 6.2.x.
@attached(body)
public macro Log(using logger: AutoLogLogger) = #externalMacro(
  module: "AutoLogMacro",
  type: "LogMacro"
)

@attached(body)
public macro Log(
  using logger: AutoLogLogger,
  emit emission: String,
  level: (any Levelable)? = nil,
  omit: any Omittable... = [],
  tag: any Taggable... = [],
  measure: Bool? = nil
) = #externalMacro(
  module: "AutoLogMacro",
  type: "LogMacro"
)

@attached(body)
public macro Log(
  using logger: AutoLogLogger,
  emit emissions: [AutoLogEmission],
  level: (any Levelable)? = nil,
  omit: any Omittable... = [],
  tag: any Taggable... = [],
  measure: Bool? = nil
) = #externalMacro(
  module: "AutoLogMacro",
  type: "LogMacro"
)

@attached(body)
public macro Log(architecture logger: AutoLogLogger) = #externalMacro(
  module: "AutoLogMacro",
  type: "LogMacro"
)

@attached(body)
public macro Log(
  architecture logger: AutoLogLogger,
  emit emission: String,
  level: (any Levelable)? = nil,
  omit: any Omittable... = [],
  tag: any Taggable... = [],
  measure: Bool? = nil
) = #externalMacro(
  module: "AutoLogMacro",
  type: "LogMacro"
)

@attached(body)
public macro Log(
  architecture logger: AutoLogLogger,
  emit emissions: [AutoLogEmission],
  level: (any Levelable)? = nil,
  omit: any Omittable... = [],
  tag: any Taggable... = [],
  measure: Bool? = nil
) = #externalMacro(
  module: "AutoLogMacro",
  type: "LogMacro"
)

/// Logs annotated function and send captured event to a ``AutoLogger`` instance.
///
/// - Parameters:
///   - logger: An instance of ``AutoLogger`` that handles events.
///   - level: The logging level of which event should be emitted.
///   - omit: The information to be omitted when capturing event.
///   - tag: The tags to be associated with captured event.
@attached(body)
public macro Log(
  using logger: any AutoLogger,
  level: (any Levelable)? = nil,
  omit: any Omittable... = [],
  tag: any Taggable... = []
) = #externalMacro(
  module: "AutoLogMacro",
  type: "LogMacro"
)

@attached(body)
public macro Log(
  using logger: any AutoLogger,
  level: (any Levelable)? = nil,
  omit: any Omittable... = [],
  tag: any Taggable... = [],
  measure: Bool
) = #externalMacro(
  module: "AutoLogMacro",
  type: "LogMacro"
)

@attached(body)
public macro Log(
  architecture logger: any AutoLogger,
  level: (any Levelable)? = nil,
  omit: any Omittable... = [],
  tag: any Taggable... = []
) = #externalMacro(
  module: "AutoLogMacro",
  type: "LogMacro"
)

@attached(body)
public macro Log(
  architecture logger: any AutoLogger,
  level: (any Levelable)? = nil,
  omit: any Omittable... = [],
  tag: any Taggable... = [],
  measure: Bool
) = #externalMacro(
  module: "AutoLogMacro",
  type: "LogMacro"
)

/// Overload for concrete `AutoLogLogger` to avoid existential boxing in
/// macro argument type-checking on Swift 6.2.x.
@attached(body)
public macro Log(
  using logger: AutoLogLogger,
  level: (any Levelable)? = nil,
  omit: any Omittable... = [],
  tag: any Taggable... = []
) = #externalMacro(
  module: "AutoLogMacro",
  type: "LogMacro"
)

@attached(body)
public macro Log(
  using logger: AutoLogLogger,
  level: (any Levelable)? = nil,
  omit: any Omittable... = [],
  tag: any Taggable... = [],
  measure: Bool
) = #externalMacro(
  module: "AutoLogMacro",
  type: "LogMacro"
)

@attached(body)
public macro Log(
  architecture logger: AutoLogLogger,
  level: (any Levelable)? = nil,
  omit: any Omittable... = [],
  tag: any Taggable... = []
) = #externalMacro(
  module: "AutoLogMacro",
  type: "LogMacro"
)

@attached(body)
public macro Log(
  architecture logger: AutoLogLogger,
  level: (any Levelable)? = nil,
  omit: any Omittable... = [],
  tag: any Taggable... = [],
  measure: Bool
) = #externalMacro(
  module: "AutoLogMacro",
  type: "LogMacro"
)

/// Associate logging level to the event emitted from attached function.
///
/// - Parameter trait: The logging level to be associated with an event.
///
/// You can use ``Level(_:)`` and macros that specify ``Levelable`` traits
/// interchengably. E.g. both bellow code snippets will produce the same result.
///
/// ```swift
/// @OSLogger
/// class Foo {
///   @OSLog(level: .fault)
///   func bar() {
///     // ...
///   }
/// }
/// ```
/// ```swift
/// @OSLogger
/// class Foo {
///   @Level(.fault)
///   @OSLog
///   func bar() {
///     // ...
///   }
/// }
/// ```
@attached(body)
public macro Level(_ trait: (any Levelable)? = nil) = #externalMacro(
  module: "AutoLogMacro",
  type: "LevelMacro"
)

/// Skips a function or initializer from being annotated with `Log` or `OSLog` macro.
///
/// ``AutoLog(using:)`` and ``OSLogged()`` implicitly introduces
/// respectively ``Log(using:)`` and ``OSLog(level:omit:tag:)
/// to all methods within attached context. Mark the member with ``Omit()``
/// to skip it.
///
/// ``Omit()`` can also be attached to a computed property as a marker without
/// producing a compiler error. Computed properties are not auto-logged today,
/// so this currently acts as a no-op marker rather than generating logging code.
///
/// ```swift
/// @AutoLog
/// struct Foo {
///   func bar() -> {
///     // ...
///   }
///
///   @Omit
///   mutating func baz() {
///     // ...
///   }
/// }
/// ```
@attached(peer)
public macro Omit() = #externalMacro(
  module: "AutoLogMacro",
  type: "OmitMacro"
)

/// Omits some information from when capturing event.
///
/// - Parameter traits: The information to be ommited when creating an event.
///
/// You can use ``Omit(_:)``  and macros that use ``Omittable`` traits
/// interchengably. E.g. both bellow code snippets will produce the same result.
///
/// ```swift
/// class Foo {
///   @Omit(.result)
///   @Log
///   func bar() -> Bar {
///     // ...
///   }
/// }
/// ```
/// ```swift
/// class Foo {
///   @Log(omit: .result)
///   func bar() -> Bar {
///     // ...
///   }
/// }
/// ```
@attached(body)
public macro Omit(_ traits: any Omittable...) = #externalMacro(
  module: "AutoLogMacro",
  type: "OmitMacro"
)

/// Conditionally omits matching result or error events using a single token.
@attached(body)
public macro Omit(
  _ trait: any Omittable,
  containing token: String,
  upToCount: Int? = nil
) = #externalMacro(
  module: "AutoLogMacro",
  type: "OmitMacro"
)

/// Conditionally omits matching result or error events using AND-matched tokens.
@attached(body)
public macro Omit(
  _ trait: any Omittable,
  containing tokens: [String],
  upToCount: Int? = nil
) = #externalMacro(
  module: "AutoLogMacro",
  type: "OmitMacro"
)

/// Conditionally omits matching result or error events for the first N occurrences.
@attached(body)
public macro Omit(
  _ trait: any Omittable,
  upToCount: Int
) = #externalMacro(
  module: "AutoLogMacro",
  type: "OmitMacro"
)


/// Associate tags with captured event.
///
/// - Parameter traits: The tags to be associated with an event.
///
/// You can use ``Tag(_:)``  and macros that use ``Taggable`` traits
/// interchengably. E.g. both bellow code snippets will produce the same result.
/// Route tags such as ``AutoLogRoute`` can also be attached here to forward
/// an event to specific sinks like `.console`, `.splunk`, or `.firebase`.
///
/// ```swift
/// class Foo {
///   @Tag("Example")
///   @Log
///   func bar() -> Bar {
///     // ...
///   }
/// }
/// ```
/// ```swift
/// class Foo {
///   @Log(tags: "Example")
///   func bar() -> Bar {
///     // ...
///   }
/// }
/// ```
@attached(body)
public macro Tag(_ traits: any Taggable...) =  #externalMacro(
  module: "AutoLogMacro",
  type: "TagMacro"
)
