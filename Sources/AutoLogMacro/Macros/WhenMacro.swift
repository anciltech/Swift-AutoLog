import SwiftDiagnostics
import SwiftSyntax

public struct WhenMacro {
  struct Message: DiagnosticMessage {
    var message: String {
      "@When macro that specifies traits must preceed @Log or @OSLog declarations."
    }

    var diagnosticID: MessageID {
      MessageID(domain: "WhenMacro", id: "1")
    }

    var severity: DiagnosticSeverity {
      DiagnosticSeverity.error
    }
  }
}

extension WhenMacro: TraitMacro {
  static let message: any DiagnosticMessage = Message()
}
