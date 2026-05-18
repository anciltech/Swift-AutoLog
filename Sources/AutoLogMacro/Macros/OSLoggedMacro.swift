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
