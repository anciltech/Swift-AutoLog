import SwiftSyntax

extension TokenKind {
  enum Predefined {
    case autoclosure
    case capture
    case using
    case architecture
    case access
    case omit
    case tag
    case Tag
    case Omit
    case Log
    case level
    case Level
    case OSLog
    case Logged
    case subsystem
    case category
    case measure
    case deduplicate
    case Deduplicate
    case when
    case When
    case containing
    case upToCount

    var identifier: TokenKind {
      switch self {
      case .access:
        return TokenKind.identifier("access")

      case .level:
        return TokenKind.identifier("level")

      case .Level:
        return TokenKind.identifier("Level")

      case .subsystem:
        return TokenKind.identifier("subsystem")

      case .OSLog:
        return TokenKind.identifier("OSLog")

      case .category:
        return TokenKind.identifier("category")

      case .capture:
        return TokenKind.identifier("capture")

      case .autoclosure:
        return TokenKind.identifier("autoclosure")

      case .using:
        return TokenKind.identifier("using")

      case .architecture:
        return TokenKind.identifier("architecture")

      case .Omit:
        return TokenKind.identifier("Omit")

      case .omit:
        return TokenKind.identifier("omit")

      case .Log:
        return TokenKind.identifier("Log")

      case .Tag:
        return TokenKind.identifier("Tag")

      case .tag:
        return TokenKind.identifier("tag")

      case .Logged:
        return TokenKind.identifier("Logged")

      case .measure:
        return TokenKind.identifier("measure")

      case .deduplicate:
        return TokenKind.identifier("deduplicate")

      case .Deduplicate:
        return TokenKind.identifier("Deduplicate")

      case .when:
        return TokenKind.identifier("when")

      case .When:
        return TokenKind.identifier("When")

      case .containing:
        return TokenKind.identifier("containing")

      case .upToCount:
        return TokenKind.identifier("upToCount")
      }
    }
  }

  static func predefined(_ token: Predefined) -> TokenKind {
    token.identifier
  }
}
