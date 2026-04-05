import SwiftDiagnostics
import SwiftSyntax

public struct DeduplicateMacro {
  struct Message: DiagnosticMessage {
    var message: String {
      "@Deduplicate macro that specifies traits must preceed @Log or @OSLog declarations."
    }

    var diagnosticID: MessageID {
      MessageID(domain: "DeduplicateMacro", id: "1")
    }

    var severity: DiagnosticSeverity {
      DiagnosticSeverity.error
    }
  }
}

extension DeduplicateMacro: TraitMacro {
  static let message: any DiagnosticMessage = Message()
}
