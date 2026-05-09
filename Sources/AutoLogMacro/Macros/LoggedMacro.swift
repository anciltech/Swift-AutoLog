import SwiftSyntax
import SwiftSyntaxMacros

public struct LoggedMacro {}

extension LoggedMacro: AutoLogAttributeMacro {
  static func ignore(_ attribute: AttributeSyntax) -> Bool {
    ignoresExistingInstrumentation(attribute, macroName: .Log)
  }

  static func introduce(for node: AttributeSyntax) -> AttributeSyntax {
    introducedAttribute(from: node, named: .Log)
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
