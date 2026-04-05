# Defining a custom AutoLogger

Define a custom ``AutoLogger`` instance and use it with macros.

## Overview

This article focuses on creating a custom `AutoLogger` instance.
The example below depends on [SentrySDK](https://github.com/getsentry/sentry-cocoa). You can also create a free account on [sentry.io](https://sentry.io/) if you want to send events to your own project.

> Code examples used throughout this article are adapted from the former Count Me In example app.
> The first line in each code snippet refers to a file within the app.

### Import Sentry and AutoLog

Since we will be extending types from both libraries, their imports must be marked as public.
```swift
// SentryLogger.swift

public import AutoLog
public import Sentry
```

### Conform to AutoLogger protocol

`AutoLogger` has two requirements, conforming type must:
* Be `Sendable`
* Implement `emit(event: AutoLogEvent, configuration: AutoLogConfiguration)` method

This method is called each time a function either completes successfully or throws an error.

```swift
// SentryLogger.swift

public import AutoLog
public import Sentry

struct SentryLogger: AutoLogger {
  func emit(event: AutoLogEvent, configuration: AutoLogConfiguration) {
    // ...
  }
}
```

### Leverage Sentry's breadcrumbs and scope

Note that not all events emitted via `emit(event:configuration:)` represent errors - successful completions of functions are also captured. We can leverage this by using Sentry's ability to attach breadcrumbs to errors when they occur, effectively creating a backtrace of user actions leading up to the failure.

> Note:
> Learn more about [breadcrumbs](https://docs.sentry.io/product/issues/issue-details/breadcrumbs/) and [scopes](https://docs.sentry.io/platforms/apple/guides/ios/enriching-events/scopes/).

```swift
// SentryLogger.swift

extension AutoLogEvent {
  var sentryBreadcrumb: Sentry.Breadcrumb {
    let breadcrumb = Sentry.Breadcrumb()
    if let level = self.level as? SentryLevel {
      breadcrumb.level = level
    }
    breadcrumb.category = "Action"
    breadcrumb.type = "user"
    breadcrumb.message = self.description
    return breadcrumb
  }

  var sentryErrorTags: [String: String] {
    [
      "error.function.signature": self.declaration,
      "error.function.parameters": self.parameters.mapValues { String(reflecting: $0) }.description,
      "error.function.location": self.location,
    ]
  }
}

```

### Implement logic

Now that we've identified the information to log on both success and failure, it's time to implement the logic that will run when the emit method is invoked.

```swift
// SentryLogger.swift

public import Sentry
public import AutoLog

struct SentryLogger: AutoLogger {
  func emit(event: AutoLogEvent, configuration _: AutoLogConfiguration) {
    switch event.result {
      case .success:
        SentrySDK.addBreadcrumb(event.sentryBreadcrumb)

      case let .failure(error):
        SentrySDK.capture(error: error) { scope in
          scope.setTags(event.sentryErrorTags)
        }
    }
  }
}
```

You can determine whether the attached function emitted a success or failure event by checking `event.result`.

On failure, we use `SentrySDK.capture(error:)`, passing in the error that triggered the event. Before sending the error to Sentry, we attach relevant metadata to the scope, providing additional context. Upon success, we simply add a breadcrumb that will be sent along with an error.

### AutoLogger extension

For cleaner syntax and easier usage of `SentryLogger`, create an extension to `AutoLogger` and declare a conditional conformance to it.

```swift
// SentryLogger.swift

extension AutoLogger where Self == SentryLogger {
  static var sentry: any AutoLogger {
    SentryLogger()
  }
}
```

> Warning:
> When creating an extension, always use `any AutoLogger` as a type, otherwise the `@AutoLog` macro will not work.

### Custom logger levels

Each logger will likely have its own predefined set of logging levels. To integrate them with macros, simply conform to the ``Levelable`` protocol.

Levelable requires that a type is `Sendable`, `ExpressibleByStringLiteral`, and implements the static method `static func level(_ value: RawValue) -> Self`.

Sentry levels are represented by the `SentryLevel` enum. To make it conform to ``Levelable``, start by adding conformance to `Sendable` and `ExpressibleByStringLiteral`.

```swift
// SentryLogger.swift

extension SentryLevel: @retroactive @unchecked Sendable {}
extension SentryLevel: @retroactive ExpressibleByStringLiteral {}
```

Now, we must fulfill the requirements of both the ``Levelable``  and ``ExpressibleByStringLiteral`` protocols.

To satisfy `Levelable` protocol, define the required static function where the `RawValue` type matches the underlying type of the extended logging level, in case of `SentryLevel` it is `UInt`. Provide a fallback level of your choice for values that don’t match predefined cases.

Additionally, implement the ``ExpressibleByStringLiteral`` initializer. This is necessary because the `@Level` macro allows you to pass either a string literal (e.g. `@Level("fatal")`) or `any Levelable` type (e.g. `@Level(.sentryFatal)`), both of which should result in the same `SentryLevel.fatal` value.

```swift
// SentryLogger.swift

extension SentryLevel: @retroactive Levelable {
  public static func level(_ value: UInt) -> Self {
    SentryLevel(rawValue: value) ?? SentryLevel.none
  }

  public init(stringLiteral value: StringLiteralType) {
    switch value {
      case "none":
        self = SentryLevel.none

      case "debug":
        self = SentryLevel.debug

      case "info":
        self = SentryLevel.info

      case "warning":
        self = SentryLevel.warning

      case "error":
        self = SentryLevel.error

      case "fatal":
        self = SentryLevel.fatal

      default:
        self = SentryLevel.none
    }
  }
}
```

### Levelable extension

As previously mentioned, macros such as ``Level(_:)`` and ``Log(using:level:omit:tag:)`` overload accept any type conforming to ``Levelable`` as a parameter. For a cleaner and more intuitive syntax, add a conditional conformance to the ``Levelable`` protocol.

> Tip:
> String conforms to ``Levelable``, ``Omittable`` and ``Taggable`` protocols.

```swift
// SentryLogger.swift

extension Levelable where Self == SentryLevel {
  static var sentryNone: any Levelable {
    SentryLevel.none
  }

  static var sentryDebug: any Levelable {
    SentryLevel.debug
  }

  static var sentryInfo: any Levelable {
    SentryLevel.info
  }

  static var sentryWarning: any Levelable {
    SentryLevel.warning
  }

  static var sentryError: any Levelable {
    SentryLevel.error
  }

  static var sentryFatal: any Levelable {
    SentryLevel.fatal
  }
}
```

### Results 

After that, any error thrown within a type or function marked with either ``AutoLog(using:)`` or ``Log(using:)`` will be sent to Sentry, including all breadcrumbs leading up to the error.


![Sentry breadcrumbs](sentry-scope)
![Sentry breadcrumbs](sentry-breadcrumbs)
