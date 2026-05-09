import SwiftSyntax
import SwiftSyntaxMacros

public struct OSLoggedMacro {}

extension OSLoggedMacro: AutoLogAttributeMacro {
  static func ignore(_ attribute: AttributeSyntax) -> Bool {
    ignoresExistingInstrumentation(attribute, macroName: .OSLog)
  }

  static func introduce(for node: AttributeSyntax) -> AttributeSyntax {
    introducedAttribute(from: node, named: .OSLog, preservingArguments: false)
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
