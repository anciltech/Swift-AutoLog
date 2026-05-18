import SwiftSyntax
import SwiftSyntaxMacros

protocol AutoLogAttributeMacro: MemberAttributeMacro {
  static func introduce(for node: AttributeSyntax) -> AttributeSyntax
  static func ignore(_ attribute: AttributeSyntax) -> Bool
}

private enum FrameworkCallbackSkips {
  static let representableProtocols: Set<String> = [
    "UIViewRepresentable",
    "UIViewControllerRepresentable",
    "NSViewRepresentable",
    "NSViewControllerRepresentable"
  ]

  static let representableLifecycleMethods: Set<String> = [
    "makeUIView",
    "updateUIView",
    "dismantleUIView",
    "makeUIViewController",
    "updateUIViewController",
    "dismantleUIViewController",
    "makeNSView",
    "updateNSView",
    "dismantleNSView",
    "makeNSViewController",
    "updateNSViewController",
    "dismantleNSViewController",
    "makeCoordinator"
  ]

  static let webKitDelegateProtocols: Set<String> = [
    "WKNavigationDelegate",
    "WKUIDelegate",
    "WKScriptMessageHandler"
  ]
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

    guard !shouldSkipFrameworkCallback(member, in: declaration) else {
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

  private static func shouldSkipFrameworkCallback(
    _ member: FunctionDeclSyntax,
    in declaration: some DeclGroupSyntax
  ) -> Bool {
    let memberName = member.name.text

    if FrameworkCallbackSkips.representableLifecycleMethods.contains(memberName),
       declaration.inherits(anyOf: FrameworkCallbackSkips.representableProtocols)
    {
      return true
    }

    if memberName == "webView",
       declaration.inherits(anyOf: FrameworkCallbackSkips.webKitDelegateProtocols)
    {
      return true
    }

    if memberName == "userContentController",
       declaration.inherits(anyOf: FrameworkCallbackSkips.webKitDelegateProtocols)
    {
      return true
    }

    return false
  }

  static func ignoresExistingInstrumentation(
    _ attribute: AttributeSyntax,
    macroName: TokenKind.Predefined
  ) -> Bool {
    guard let identifierType = IdentifierTypeSyntax(attribute.attributeName) else {
      return false
    }

    if identifierType.name.tokenKind == .predefined(macroName) {
      return true
    }

    if identifierType.name.tokenKind == .predefined(.Omit), attribute.arguments == nil {
      return true
    }

    return false
  }

  static func introducedAttribute(
    from node: AttributeSyntax,
    named macroName: TokenSyntax.Predefined,
    preservingArguments: Bool = true
  ) -> AttributeSyntax {
    guard preservingArguments else {
      return AttributeSyntax(
        TypeSyntax(
          IdentifierTypeSyntax(
            name: TokenSyntax.predefined(macroName)
          )
        )
      )
    }

    var syntax = node
    syntax.attributeName = TypeSyntax(
      IdentifierTypeSyntax(
        name: TokenSyntax.predefined(macroName)
      )
    )
    return syntax
  }
}
