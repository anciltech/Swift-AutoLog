import SwiftSyntax

extension TokenSyntax {
  enum Predefined {
    case `_`
    case doubleQuestionMark
    case log
    case level
    case tags
    case Log
    case OSLog
    case emit
    case event
    case Event
    case error
    case result
    case location
    case `default`
    case failure
    case success
    case autoLogger
    case logger
    case Logger
    case AutoLogger
    case parameters
    case declaration
    case source
    case AutoLogSource
    case Conformance
    case AutoLogEvent
    case Omit
    case Redact
    case subsystem
    case category
    case bundleIdentifier
    case Bundle
    case main
    case emitStart
    case duration
    case isMeasuredExplicitly
    case ContinuousClock
    case now
    case __logStart

    var identifier: TokenSyntax {
      switch self {
      case ._:
        return TokenSyntax.identifier("_")
          
        case .level:
          return TokenSyntax.identifier("level")

      case .doubleQuestionMark:
        return TokenSyntax.identifier("??")

      case .bundleIdentifier:
        return TokenSyntax.identifier("bundleIdentifier")

      case .Bundle:
        return TokenSyntax.identifier("Bundle")

      case .main:
        return TokenSyntax.identifier("main")

      case .logger:
        return TokenSyntax.identifier("logger")

      case .Logger:
        return TokenSyntax.identifier("Logger")

      case .subsystem:
        return TokenSyntax.identifier("subsystem")

      case .category:
        return TokenSyntax.identifier("category")

      case .failure:
        return TokenSyntax.identifier("failure")

      case .success:
        return TokenSyntax.identifier("success")

      case .tags:
        return TokenSyntax.identifier("tags")

      case .log:
        return TokenSyntax.identifier("log")

      case .Log:
        return TokenSyntax.identifier("Log")

      case .OSLog:
        return TokenSyntax.identifier("OSLog")

      case .emit:
        return TokenSyntax.identifier("emit")

      case .event:
        return TokenSyntax.identifier("event")

      case .Event:
        return TokenSyntax.identifier("Event")

      case .error:
        return TokenSyntax.identifier("error")

      case .result:
        return TokenSyntax.identifier("result")

      case .location:
        return TokenSyntax.identifier("location")

      case .default:
        return TokenSyntax.identifier("default")

      case .autoLogger:
        return TokenSyntax.identifier("autoLogger")

      case .AutoLogger:
        return TokenSyntax.identifier("AutoLogger")

      case .parameters:
        return TokenSyntax.identifier("parameters")

      case .declaration:
        return TokenSyntax.identifier("declaration")

      case .Conformance:
        return TokenSyntax.identifier("Conformance")

      case .AutoLogEvent:
        return TokenSyntax.identifier("AutoLogEvent")

      case .Omit:
        return TokenSyntax.identifier("Omit")

      case .Redact:
        return TokenSyntax.identifier("Redact")

      case .source:
        return TokenSyntax.identifier("source")

      case .AutoLogSource:
        return TokenSyntax.identifier("AutoLogSource")

      case .emitStart:
        return TokenSyntax.identifier("emitStart")

      case .duration:
        return TokenSyntax.identifier("duration")

      case .isMeasuredExplicitly:
        return TokenSyntax.identifier("isMeasuredExplicitly")

      case .ContinuousClock:
        return TokenSyntax.identifier("ContinuousClock")

      case .now:
        return TokenSyntax.identifier("now")

      case .__logStart:
        return TokenSyntax.identifier("__logStart")
      }
    }
  }

  static func predefined(_ token: Predefined) -> TokenSyntax {
    token.identifier
  }

  var isAccessModifier: Bool {
    Self.accessLevels.contains(self.tokenKind)
  }

  private static let accessLevels = [
    TokenKind.keyword(.open),
    TokenKind.keyword(.final),
    TokenKind.keyword(.public),
    TokenKind.keyword(.package),
    TokenKind.keyword(.internal),
    TokenKind.keyword(.fileprivate),
    TokenKind.keyword(.private),
  ]
}
