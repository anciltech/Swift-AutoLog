import SwiftSyntax
import SwiftSyntaxMacros

protocol AutoLogAttributeMacro: MemberAttributeMacro {
  static func introduce(for node: AttributeSyntax) -> AttributeSyntax
  static func ignore(_ attribute: AttributeSyntax) -> Bool
}

extension AutoLogAttributeMacro {
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingAttributesFor member: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [AttributeSyntax] {
    guard let member = FunctionDeclSyntax(member) else {
      return self.attributes()
    }

    let canExpand = member.attributes.map { attribute in
      guard case let .attribute(syntax) = attribute else { return false }
      return self.ignore(syntax)
    }

    return canExpand.contains(true)
      ? self.attributes()
      : self.attributes {
        self.introduce(for: node)
      }
  }
}
