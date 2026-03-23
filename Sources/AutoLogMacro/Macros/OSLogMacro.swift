import SwiftSyntax

public struct OSLogMacro {}

extension OSLogMacro: AutoLogMacro {
  static func initialize(for node: AttributeSyntax) -> ExprSyntax {
    ExprSyntax(
      MemberAccessExprSyntax(
        base: DeclReferenceExprSyntax(baseName: .keyword(.Self)),
        declName: DeclReferenceExprSyntax(baseName: .predefined(.logger))
      )
    )
  }
}
