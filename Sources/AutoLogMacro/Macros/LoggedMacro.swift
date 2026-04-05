import SwiftSyntax
import SwiftSyntaxMacros

public struct LoggedMacro {}

extension LoggedMacro: AutoLogAttributeMacro {
  static func ignore(_ attribute: AttributeSyntax) -> Bool {
    guard let identifierType = IdentifierTypeSyntax(attribute.attributeName) else {
      return false
    }

    switch identifierType.name.tokenKind {
    case .predefined(.Log):
      return true

    case .predefined(.Omit) where attribute.arguments == nil:
      return true

    default:
      return false
    }
  }

  static func introduce(for node: AttributeSyntax) -> AttributeSyntax {
    var syntax = node
    syntax.attributeName = TypeSyntax(
      IdentifierTypeSyntax(
        name: .predefined(.Log)
      )
    )
    return syntax
  }
}

extension LoggedMacro: ExtensionMacro {
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    self.conformance {
      // Emit an empty extension so editor macro expansion has a concrete type-level
      // result even when @AutoLog only injects member attributes.
      ExtensionDeclSyntax(
        extendedType: type
      ) {}
    }
  }
}
