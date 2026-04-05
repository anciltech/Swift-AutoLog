import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct AutoLogPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    LogMacro.self,
    LoggedMacro.self,
    OSLogMacro.self,
    OSLoggerMacro.self,
    OSLoggedMacro.self,
    LevelMacro.self,
    DeduplicateMacro.self,
    OmitMacro.self,
    TagMacro.self
  ]
}
