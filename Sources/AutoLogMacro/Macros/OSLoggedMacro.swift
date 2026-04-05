import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

public struct OSLoggedMacro {}

extension OSLoggedMacro: AutoLogAttributeMacro {
  static func ignore(_ attribute: AttributeSyntax) -> Bool {
    guard let identifierType = IdentifierTypeSyntax(attribute.attributeName) else {
      return false
    }

    switch identifierType.name.tokenKind {
    case .predefined(.OSLog):
      return true

    case .predefined(.Omit) where attribute.arguments == nil:
      return true

    default:
      return false
    }
  }

  static func introduce(for node: AttributeSyntax) -> AttributeSyntax {
    AttributeSyntax(
      TypeSyntax(
        IdentifierTypeSyntax(name: .predefined(.OSLog))
      )
    )
  }
}

extension OSLoggedMacro: ExtensionMacro {
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    self.conformance {
      // Keep editor expansion parity with @AutoLog by emitting a concrete
      // type-level result even when only member attributes are introduced.
      ExtensionDeclSyntax(
        extendedType: type
      ) {}
    }
  }
}
