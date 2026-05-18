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
