import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

protocol AutoLogMacro: BodyMacro {
  static func initialize(for node: AttributeSyntax) -> ExprSyntax
}

struct EarlyExitContext {
  enum Kind {
    case `guard`
    case `if`
    case elseif
    case `else`
    case switchCase
    case switchDefault
  }

  let kind: Kind
  let branchCondition: String?
  let effectiveCondition: String?
  let branchConditionExpression: ExprSyntax?
  let effectiveConditionExpression: ExprSyntax?

  init(
    kind: Kind,
    branchCondition: String?,
    effectiveCondition: String?,
    branchConditionExpression: ExprSyntax? = nil,
    effectiveConditionExpression: ExprSyntax? = nil
  ) {
    self.kind = kind
    self.branchCondition = branchCondition
    self.effectiveCondition = effectiveCondition
    self.branchConditionExpression = branchConditionExpression
    self.effectiveConditionExpression = effectiveConditionExpression
  }
}

private extension String {
  var indentedInitializerExitBranch: String {
    split(separator: "\n", omittingEmptySubsequences: false)
      .map { "  \($0)" }
      .joined(separator: "\n")
  }
}

struct AutoLogConditionTracePlan {
  let variableName: String
  let originalCondition: String
  let tracedConditionExpression: String

  var declaration: CodeBlockItemSyntax {
    CodeBlockItemSyntax(
      stringLiteral: "var \(variableName) = AutoLogConditionTrace.Evaluator()"
    )
  }

  var passedCondition: ConditionElementListSyntax {
    ConditionElementListSyntax {
      ConditionElementSyntax(
        condition: .expression(
          ExprSyntax(stringLiteral: tracedConditionExpression)
        )
      )
    }
  }

  var passingDescriptionExpression: ExprSyntax {
    descriptionExpression(member: "passingDescription", fallback: originalCondition)
  }

  var failingDescriptionExpression: ExprSyntax {
    descriptionExpression(member: "failingDescription", fallback: "!(\(originalCondition))")
  }

  private func descriptionExpression(member: String, fallback: String) -> ExprSyntax {
    let passed = member == "passingDescription" ? "true" : "false"
    return ExprSyntax(
      stringLiteral: "AutoLogConditionTrace(expression: \"\(Self.escaped(originalCondition))\", passed: \(passed), terms: \(variableName).terms).\(member) ?? \"\(Self.escaped(fallback))\""
    )
  }

  static func escaped(_ value: String) -> String {
    value
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
  }
}

struct AutoLogDeclarationMetadata {
  let location: StringLiteralExprSyntax
  let description: String
  let parameters: [FunctionSyntax.Signature.Parameter]
}

struct AutoLogEmissionPlan {
  let emitsStart: Bool
  let emitsSuccess: Bool
  let emitsFailure: Bool
  let emitsHandledErrors: Bool

  var emitsCompletion: Bool {
    emitsSuccess || emitsFailure
  }

  static let all = AutoLogEmissionPlan(
    emitsStart: true,
    emitsSuccess: true,
    emitsFailure: true,
    emitsHandledErrors: true
  )

  struct UnsupportedEmissionDiagnostic: DiagnosticMessage {
    let value: String

    var message: String {
      "AutoLog emit: expects a typed value such as .failures or a typed array such as [.failures, .warnings]; received \(value)"
    }

    var diagnosticID: MessageID {
      MessageID(domain: "AutoLogEmission", id: "unsupported")
    }

    var severity: DiagnosticSeverity {
      .error
    }
  }

  static func resolved(
    from node: AttributeSyntax,
    in context: some MacroExpansionContext
  ) -> Self {
    guard let expression = node.extract(argument: .emit, as: ExprSyntax.self) else {
      return .all
    }

    guard let tokens = emissionTokens(from: expression),
          let plan = plan(for: tokens)
    else {
      context.diagnose(
        Diagnostic(
          node: Syntax(expression),
          message: UnsupportedEmissionDiagnostic(value: expression.trimmedDescription)
        )
      )
      return .all
    }

    return plan
  }

  private static func plan(for tokens: [String]) -> Self? {
    guard !tokens.isEmpty else { return nil }

    var emitsStart = false
    var emitsSuccess = false
    var emitsFailure = false
    var emitsHandledErrors = false

    for token in tokens {
      switch normalizedToken(token) {
      case "all":
        return .all
      case "completions":
        emitsSuccess = true
        emitsFailure = true
        emitsHandledErrors = true
      case "successes":
        emitsSuccess = true
      case "failures":
        emitsFailure = true
      case "warnings":
        emitsHandledErrors = true
      case "starts":
        emitsStart = true
      default:
        return nil
      }
    }

    return AutoLogEmissionPlan(
      emitsStart: emitsStart,
      emitsSuccess: emitsSuccess,
      emitsFailure: emitsFailure,
      emitsHandledErrors: emitsHandledErrors
    )
  }

  private static func emissionTokens(from expression: ExprSyntax) -> [String]? {
    if let array = expression.as(ArrayExprSyntax.self) {
      return array.elements.compactMap { element in
        tokenValue(element.expression)
      }
    }

    guard let value = tokenValue(expression) else { return nil }
    return [value]
  }

  private static func tokenValue(_ expression: ExprSyntax) -> String? {
    guard !expression.is(StringLiteralExprSyntax.self) else { return nil }
    return expression.trimmedDescription
      .replacingOccurrences(of: " ", with: "")
      .replacingOccurrences(of: "AutoLogEmission.", with: "")
      .replacingOccurrences(of: ".", with: "")
  }

  private static func normalizedToken(_ value: String) -> String {
    value
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: "AutoLogEmission.", with: "")
      .replacingOccurrences(of: ".", with: "")
      .replacingOccurrences(of: "_", with: "")
      .replacingOccurrences(of: "-", with: "")
      .lowercased()
  }
}

extension AutoLogMacro {
  public static func initialize(for node: AttributeSyntax) -> ExprSyntax {
    if let expression = node.extract(argument: .architecture, as: ExprSyntax.self) {
      return expression
    }

    if let expression = node.extract(argument: .using, as: ExprSyntax.self) {
      return expression
    }

    return ExprSyntax(
      MemberAccessExprSyntax(
        base: DeclReferenceExprSyntax(
          baseName: .identifier("runtime")
        ),
        period: .periodToken(),
        name: .identifier("logger")
      )
    )
  }

  public static func expansion(
    of node: AttributeSyntax,
    providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax,
    in context: some MacroExpansionContext
  ) throws -> [CodeBlockItemSyntax] {
    if let function = FunctionSyntax(from: declaration) {
      return self.expansion(
        of: node,
        providingBodyFor: function,
        in: context
      )
    }

    if let initializer = InitializerSyntax(from: declaration) {
      return self.expansion(
        of: node,
        providingBodyFor: initializer,
        in: context
      )
    }

    return self.body()
  }

  static func expansion(
    of node: AttributeSyntax,
    providingBodyFor function: FunctionSyntax,
    in context: some MacroExpansionContext
  ) -> [CodeBlockItemSyntax] {
    if function.syntax.attributes.hasBareOmitMarker {
      return function.body
    }

    // Extract measure: Bool? from @Log(measure: ...).
    // nil → default (generate timing, not explicitly requested)
    // true → generate timing, mark as explicitly requested
    // false → suppress timing code entirely
    let measureTrait = node.extract(argument: .measure, as: BooleanLiteralExprSyntax.self)
    let shouldMeasure: Bool
    let isMeasuredExplicitly: Bool
    if let measureTrait {
      shouldMeasure = measureTrait.literal.tokenKind == .keyword(.true)
      isMeasuredExplicitly = shouldMeasure
    } else {
      shouldMeasure = true
      isMeasuredExplicitly = false
    }

    let emission = AutoLogEmissionPlan.resolved(from: node, in: context)
    let tagTraits = function.syntax.attributes.extractTagTraitsInSourceOrder()
    let omitTraits = function.syntax.attributes.extractTraits(for: .omit)
    let levelTrait = function.syntax.attributes.extractTraits(for: .level).first
    let deduplicationTrait = function.syntax.attributes.extractTraits(for: .deduplicate).first
    let resultFilterTrait = function.syntax.attributes.extractTraits(for: .when).first
    let omitRuleTraits = function.syntax.attributes.extractOmitRuleTraits()
    let emitsThrownFailure = function.isThrowing && emission.emitsFailure
    let emitsAnyEvent = emission.emitsStart
      || emission.emitsSuccess
      || emitsThrownFailure
      || emission.emitsHandledErrors

    guard emitsAnyEvent else {
      return function.body
    }

    let instrumentedPlain = self.instrumentedPlain(
      of: function,
      capturesHandledErrors: emission.emitsHandledErrors
    )
    let capturesTiming = shouldMeasure && (emission.emitsSuccess || emitsThrownFailure)
    let metadata = AutoLogDeclarationMetadata(
      location: self.location(of: function, in: context),
      description: function.description,
      parameters: function.parameters
    )

    return body {
      self.captureRuntime()
      self.hook(for: node)
      self.event(
        for: node,
        of: metadata,
        levelTrait: levelTrait,
        taggableTraits: tagTraits,
        omittableTraits: omitTraits,
        deduplicationTrait: deduplicationTrait,
        omitRuleTraits: omitRuleTraits
      )

      if isMeasuredExplicitly && capturesTiming {
        self.captureExplicitMeasure()
      }

      if emission.emitsStart {
        self.emitStart()
      }

      if capturesTiming {
        self.captureTimingStart()
      }

      switch function.isThrowing {
        case false where function.isVoid:
          CodeBlockItemSyntax(instrumentedPlain)
          CodeBlockItemSyntax.call(function)
          if emission.emitsSuccess {
            if capturesTiming { self.captureTimingEnd() }
            self.emit()
          }

        case true where function.isVoid:
          CodeBlockItemSyntax(instrumentedPlain)
          CodeBlockItemSyntax.try {
            CodeBlockItemSyntax.call(function)
            if emission.emitsSuccess {
              if capturesTiming { self.captureTimingEnd() }
              self.emit()
            }
          } catch: {
            if emission.emitsFailure {
              self.capture(.error)
              if capturesTiming { self.captureTimingEnd() }
              self.emit()
            }
            CodeBlockItemSyntax.rethrow
          }

        case true:
          CodeBlockItemSyntax(instrumentedPlain)
          CodeBlockItemSyntax.try {
            CodeBlockItemSyntax.call(function)
            if emission.emitsSuccess {
              if !omitTraits.contains(where: \.isOmitResult) {
                self.capture(.result, boxesValue: function.returnsOptionalLike)
              }
              if capturesTiming { self.captureTimingEnd() }
              self.emit(when: resultFilterTrait)
            }
            CodeBlockItemSyntax.return
          } catch: {
            if emission.emitsFailure {
              self.capture(.error)
              if capturesTiming { self.captureTimingEnd() }
              self.emit()
            }
            CodeBlockItemSyntax.rethrow
          }

        case false:
          CodeBlockItemSyntax(instrumentedPlain)
          CodeBlockItemSyntax.call(function)
          if emission.emitsSuccess {
            if !omitTraits.contains(where: \.isOmitResult) {
              self.capture(.result, boxesValue: function.returnsOptionalLike)
            }
            if capturesTiming { self.captureTimingEnd() }
            self.emit(when: resultFilterTrait)
          }
          CodeBlockItemSyntax.return
      }
    }
  }

  static func expansion(
    of node: AttributeSyntax,
    providingBodyFor initializer: InitializerSyntax,
    in context: some MacroExpansionContext
  ) -> [CodeBlockItemSyntax] {
    if initializer.syntax.attributes.hasBareOmitMarker {
      return initializer.body
    }

    let measureTrait = node.extract(argument: .measure, as: BooleanLiteralExprSyntax.self)
    let shouldMeasure: Bool
    let isMeasuredExplicitly: Bool
    if let measureTrait {
      shouldMeasure = measureTrait.literal.tokenKind == .keyword(.true)
      isMeasuredExplicitly = shouldMeasure
    } else {
      shouldMeasure = true
      isMeasuredExplicitly = false
    }

    let emission = AutoLogEmissionPlan.resolved(from: node, in: context)
    let tagTraits = initializer.syntax.attributes.extractTagTraitsInSourceOrder()
    let omitTraits = initializer.syntax.attributes.extractTraits(for: .omit)
    let levelTrait = initializer.syntax.attributes.extractTraits(for: .level).first
    let deduplicationTrait = initializer.syntax.attributes.extractTraits(for: .deduplicate).first
    let omitRuleTraits = initializer.syntax.attributes.extractOmitRuleTraits()
    let emitsThrownFailure = initializer.isThrowing && emission.emitsFailure
    let emitsAnyEvent = emission.emitsStart
      || emission.emitsSuccess
      || emitsThrownFailure
      || emission.emitsHandledErrors

    guard emitsAnyEvent else {
      return initializer.body
    }

    let capturesTiming = shouldMeasure && (
      emission.emitsSuccess || emitsThrownFailure
    )
    let metadata = AutoLogDeclarationMetadata(
      location: self.location(of: initializer, in: context),
      description: initializer.description,
      parameters: initializer.parameters
    )

    return body {
      self.captureRuntime()
      self.hook(for: node)
      self.event(
        for: node,
        of: metadata,
        levelTrait: levelTrait,
        taggableTraits: tagTraits,
        omittableTraits: omitTraits,
        deduplicationTrait: deduplicationTrait,
        omitRuleTraits: omitRuleTraits
      )

      if isMeasuredExplicitly && capturesTiming {
        self.captureExplicitMeasure()
      }

      if emission.emitsStart {
        self.emitStart()
      }

      if capturesTiming {
        self.captureTimingStart()
      }

      if initializer.isThrowing {
        CodeBlockItemSyntax(stringLiteral: "var __logError: (any Error)?")
      }

      if let initializerExit = self.emitOnInitializerExit(
        shouldMeasure: capturesTiming,
        capturesError: initializer.isThrowing,
        emission: emission
      ) {
        initializerExit
      }

      if initializer.isThrowing {
        self.throwingInitializerBody(
          of: initializer,
          capturesHandledErrors: emission.emitsHandledErrors
        )
      } else {
        self.instrumentedBody(
          of: initializer,
          capturesHandledErrors: emission.emitsHandledErrors
        )
      }
    }
  }

  static func location(
    of function: FunctionSyntax,
    in context: some MacroExpansionContext
  ) -> StringLiteralExprSyntax {
    StringLiteralExprSyntax(
      content: context.location(of: function.syntax)?.findable ?? ""
    )
  }

  static func location(
    of initializer: InitializerSyntax,
    in context: some MacroExpansionContext
  ) -> StringLiteralExprSyntax {
    StringLiteralExprSyntax(
      content: context.location(of: initializer.syntax)?.findable ?? ""
    )
  }

  static func hook(
    for node: AttributeSyntax
  ) -> CodeBlockItemSyntax {
    return CodeBlockItemSyntax(
      VariableDeclSyntax(
        bindingSpecifier: .keyword(.let),
        bindings: PatternBindingListSyntax(
          arrayLiteral: PatternBindingSyntax(
            pattern: IdentifierPatternSyntax(
              identifier: .predefined(.autoLogger)
            ),
            typeAnnotation: TypeAnnotationSyntax(
              type: SomeOrAnyTypeSyntax(
                someOrAnySpecifier: .keyword(.any),
                constraint: IdentifierTypeSyntax(
                  name: .predefined(.AutoLogger)
                )
              )
            ),
            initializer: InitializerClauseSyntax(
              value: self.initialize(for: node)
            )
          )
        )
      )
    )
  }

  static func captureRuntime() -> CodeBlockItemSyntax {
    CodeBlockItemSyntax(
      VariableDeclSyntax(
        bindingSpecifier: .keyword(.let),
        bindings: PatternBindingListSyntax(
          arrayLiteral: PatternBindingSyntax(
            pattern: IdentifierPatternSyntax(
              identifier: .identifier("runtime")
            ),
            initializer: InitializerClauseSyntax(
              value: FunctionCallExprSyntax(
                calledExpression: MemberAccessExprSyntax(
                  base: DeclReferenceExprSyntax(baseName: .identifier("AutoLog")),
                  period: .periodToken(),
                  name: .identifier("runtimeSnapshot")
                ),
                leftParen: .leftParenToken(),
                arguments: LabeledExprListSyntax(),
                rightParen: .rightParenToken()
              )
            )
          )
        )
      )
    )
  }

  static func event(
    for node: AttributeSyntax,
    of declaration: AutoLogDeclarationMetadata,
    levelTrait: (any ExprSyntaxProtocol)?,
    taggableTraits: [ExprSyntax],
    omittableTraits: [any ExprSyntaxProtocol],
    deduplicationTrait: (any ExprSyntaxProtocol)?,
    omitRuleTraits: [AttributeListSyntax.OmitRuleTrait]
  ) -> CodeBlockItemSyntax {
    let capturedParameters = declaration.parameters.filter { parameter in
      !omittableTraits.contains(where: { trait in trait.isOmitParameter(parameter.name) })
    }
    let capturesParameters = !omittableTraits.contains(where: \.isOmitParameters)
      && !capturedParameters.isEmpty
    let capturesTags = !taggableTraits.isEmpty
    let hasDeduplication = deduplicationTrait != nil
    let hasOmissionRules = !omitRuleTraits.isEmpty

    return CodeBlockItemSyntax(
      VariableDeclSyntax(
        // Always `var` — timing (`event.duration`) and result are assigned post-construction.
        bindingSpecifier: .keyword(.var),
        bindings: PatternBindingListSyntax(
          arrayLiteral: PatternBindingSyntax(
            pattern: IdentifierPatternSyntax(identifier: .predefined(.event)),
            initializer: InitializerClauseSyntax(
              value: FunctionCallExprSyntax(
                calledExpression: DeclReferenceExprSyntax(
                  baseName: .predefined(.AutoLogEvent)
                ),
                leftParen: .leftParenToken(),
                arguments: LabeledExprListSyntax {
                  // MARK: - level: (any Levelable)?
                  if let level = levelTrait {
                    LabeledExprSyntax(
                      leadingTrivia: .newline,
                      label: .predefined(.level),
                      colon: .colonToken(),
                      expression: level,
                      trailingComma: .commaToken()
                    )
                  }

                  // MARK: - source: (any Sourceable)?
                  LabeledExprSyntax(
                    leadingTrivia: .newline,
                    label: .predefined(.source),
                    colon: .colonToken(),
                    expression: MemberAccessExprSyntax(
                      base: DeclReferenceExprSyntax(
                        baseName: .predefined(.AutoLogSource)
                      ),
                      period: .periodToken(),
                      name: TokenSyntax.identifier("current")
                    ),
                    trailingComma: .commaToken(),
                    trailingTrivia: .newline
                  )

                  // MARK: - callSiteDepth: Int?
                  LabeledExprSyntax(
                    leadingTrivia: .newline,
                    label: .identifier("callSiteDepth"),
                    colon: .colonToken(),
                    expression: MemberAccessExprSyntax(
                      base: DeclReferenceExprSyntax(
                        baseName: .predefined(.AutoLogSource)
                      ),
                      period: .periodToken(),
                      name: TokenSyntax.identifier("nextCallSiteDepth")
                    ),
                    trailingComma: .commaToken(),
                    trailingTrivia: .newline
                  )

                  // MARK: - location: String
                  LabeledExprSyntax(
                    leadingTrivia: .newline,
                    label: .predefined(.location),
                    colon: .colonToken(),
                    expression: declaration.location,
                    trailingComma: .commaToken(),
                    trailingTrivia: .newline
                  )

                  // MARK: - declaration: String
                  LabeledExprSyntax(
                    label: .predefined(.declaration),
                    colon: .colonToken(),
                    expression: StringLiteralExprSyntax(content: declaration.description),
                    trailingComma: capturesParameters || capturesTags || hasDeduplication || hasOmissionRules
                      ? .commaToken()
                      : nil,
                    trailingTrivia: .newline
                  )

                  // MARK: - parameters: [String: Any]
                  if capturesParameters {
                    LabeledExprSyntax(
                      label: .predefined(.parameters),
                      colon: .colonToken(),
                      expression: DictionaryExprSyntax(
                        leftSquare: .leftSquareToken(
                          trailingTrivia: .newline
                        ),
                        rightSquare: .rightSquareToken(
                          leadingTrivia: .newline
                        )
                      ) {
                        DictionaryElementListSyntax {
                          capturedParameters.map { parameter in
                            return DictionaryElementSyntax(
                              key: StringLiteralExprSyntax(content: parameter.name.text),
                              value: parameterMetadataExpression(for: parameter),
                              trailingComma: .commaToken(
                                presence: capturedParameters.last == parameter ? .missing : .present
                              ),
                              trailingTrivia: .newline
                            )
                          }
                        }
                      },
                      trailingComma: capturesTags || hasDeduplication || hasOmissionRules
                        ? .commaToken()
                        : nil,
                      trailingTrivia: .newline
                    )
                  }

                  // MARK: - Tags
                  if capturesTags {
                    LabeledExprSyntax(
                      label: .predefined(.tags),
                      colon: .colonToken(),
                      expression: ArrayExprSyntax(
                        elements: ArrayElementListSyntax {
                          taggableTraits.map { trait in
                            ArrayElementSyntax(expression: trait)
                          }
                        }
                      ),
                      trailingComma: hasDeduplication || hasOmissionRules ? .commaToken() : nil,
                      trailingTrivia: hasDeduplication || hasOmissionRules ? [] : .newline
                    )
                  }

                  if let deduplicationTrait {
                    LabeledExprSyntax(
                      label: .identifier("deduplicateWithin"),
                      colon: .colonToken(),
                      expression: deduplicationTrait,
                      trailingComma: omitRuleTraits.isEmpty ? nil : .commaToken(),
                      trailingTrivia: omitRuleTraits.isEmpty ? .newline : []
                    )
                  }

                  if !omitRuleTraits.isEmpty {
                    LabeledExprSyntax(
                      label: .identifier("omissionRules"),
                      colon: .colonToken(),
                      expression: ArrayExprSyntax(
                        elements: ArrayElementListSyntax {
                          omitRuleTraits.map { omitRule in
                            ArrayElementSyntax(
                              expression: FunctionCallExprSyntax(
                                calledExpression: DeclReferenceExprSyntax(
                                  baseName: .identifier("AutoLogOmissionRule")
                                ),
                                leftParen: .leftParenToken(),
                                arguments: LabeledExprListSyntax {
                                  LabeledExprSyntax(
                                    label: .identifier("scope"),
                                    colon: .colonToken(),
                                    expression: Self.omitRuleScopeExpression(omitRule.scope),
                                    trailingComma: .commaToken()
                                  )
                                  LabeledExprSyntax(
                                    label: .identifier("tokens"),
                                    colon: .colonToken(),
                                    expression: Self.omitRuleTokensExpression(omitRule.containing),
                                    trailingComma: omitRule.upToCount == nil ? nil : .commaToken()
                                  )
                                  if let upToCount = omitRule.upToCount {
                                    LabeledExprSyntax(
                                      label: .identifier("upToCount"),
                                      colon: .colonToken(),
                                      expression: upToCount
                                    )
                                  }
                                },
                                rightParen: .rightParenToken()
                              )
                            )
                          }
                        }
                      ),
                      trailingTrivia: .newline
                    )
                  }
                },
                rightParen: .rightParenToken()
              )
            )
          )
        )
      )
    )
  }

  static func omitRuleTokensExpression(
    _ containing: ExprSyntax?
  ) -> ExprSyntax {
    guard let containing else {
      return ExprSyntax(ArrayExprSyntax(elements: ArrayElementListSyntax()))
    }

    if containing.is(ArrayExprSyntax.self) {
      return containing
    }

    return ExprSyntax(
      ArrayExprSyntax(
        elements: ArrayElementListSyntax {
          ArrayElementSyntax(expression: containing)
        }
      )
    )
  }

  static func omitRuleScopeExpression(
    _ scope: ExprSyntax
  ) -> ExprSyntax {
    ExprSyntax(
      MemberAccessExprSyntax(
        base: DeclReferenceExprSyntax(baseName: .identifier("AutoLogOmissionRule.Scope")),
        period: .periodToken(),
        name: .identifier(scope.isOmitError ? "error" : "result")
      )
    )
  }

  static func parameterMetadataExpression(
    for parameter: FunctionSyntax.Signature.Parameter
  ) -> ExprSyntax {
    let value = DeclReferenceExprSyntax(baseName: parameter.name.trimmed)
    guard parameter.isOptionalLike else { return ExprSyntax(value) }
    return metadataBoxExpression(value)
  }

  static func metadataBoxExpression(_ expression: some ExprSyntaxProtocol) -> ExprSyntax {
    ExprSyntax(
      FunctionCallExprSyntax(
        calledExpression: MemberAccessExprSyntax(
          base: DeclReferenceExprSyntax(baseName: .identifier("AutoLogMetadata")),
          period: .periodToken(),
          name: .identifier("box")
        ),
        leftParen: .leftParenToken(),
        arguments: LabeledExprListSyntax {
          LabeledExprSyntax(expression: expression)
        },
        rightParen: .rightParenToken()
      )
    )
  }

  static func capture(
    _ baseName: TokenSyntax.Predefined,
    boxesValue: Bool = false
  ) -> CodeBlockItemSyntax {
    let capturedValue = DeclReferenceExprSyntax(baseName: baseName.identifier)
    return CodeBlockItemSyntax(
      InfixOperatorExprSyntax(
        leftOperand: MemberAccessExprSyntax(
          base: DeclReferenceExprSyntax(baseName: .predefined(.event)),
          name: TokenSyntax.predefined(.result)
        ),
        operator: AssignmentExprSyntax(),
        rightOperand: FunctionCallExprSyntax(
          calledExpression: MemberAccessExprSyntax(
            name: TokenSyntax.predefined(baseName == .result ? .success : .failure)
          ),
          leftParen: .leftParenToken(),
          arguments: LabeledExprListSyntax {
            LabeledExprSyntax(
              expression: boxesValue
                ? metadataBoxExpression(capturedValue)
                : ExprSyntax(capturedValue)
            )
          },
          rightParen: .rightParenToken()
        )
      )
    )
  }

  /// Generates:
  /// `autoLogger.emitIfEnabled(event: event, runtime: runtime)`
  static func emit(
    when resultFilterTrait: (any ExprSyntaxProtocol)? = nil
  ) -> CodeBlockItemSyntax {
    if let resultFilterTrait {
      return CodeBlockItemSyntax(
        IfExprSyntax(
          conditions: ConditionElementListSyntax {
            ConditionElementSyntax(
              condition: .expression(
                ExprSyntax(
                  InfixOperatorExprSyntax(
                  leftOperand: DeclReferenceExprSyntax(baseName: .predefined(.result)),
                  operator: BinaryOperatorExprSyntax(
                    operator: .binaryOperator("==")
                  ),
                  rightOperand: ExprSyntax(fromProtocol: resultFilterTrait)
                  )
                )
              )
            )
          },
          body: CodeBlockSyntax(
            statements: CodeBlockItemListSyntax {
              self.emit()
            }
          )
        )
      )
    }

    return CodeBlockItemSyntax(
      FunctionCallExprSyntax(
        calledExpression: MemberAccessExprSyntax(
          base: DeclReferenceExprSyntax(
            baseName: .predefined(.autoLogger)
          ),
          period: .periodToken(),
          name: .identifier("emitIfEnabled")
        ),
        leftParen: .leftParenToken(),
        arguments: LabeledExprListSyntax(
          arrayLiteral:
            LabeledExprSyntax(
              label: .predefined(.event),
              colon: .colonToken(),
              expression: DeclReferenceExprSyntax(baseName: .predefined(.event)),
              trailingComma: .commaToken()
            ),
            LabeledExprSyntax(
              label: .identifier("runtime"),
              colon: .colonToken(),
              expression: DeclReferenceExprSyntax(baseName: .identifier("runtime"))
            )
        ),
        rightParen: .rightParenToken()
      )
    )
  }

  /// Generates:
  /// `autoLogger.emitStart(event: event, runtime: runtime)`
  ///
  /// The `emitStart` default implementation on `AutoLogger` checks the
  /// configuration captured at function entry before emitting.
  static func emitStart() -> CodeBlockItemSyntax {
    CodeBlockItemSyntax(
      FunctionCallExprSyntax(
        calledExpression: MemberAccessExprSyntax(
          base: DeclReferenceExprSyntax(baseName: .predefined(.autoLogger)),
          period: .periodToken(),
          name: .predefined(.emitStart)
        ),
        leftParen: .leftParenToken(),
        arguments: LabeledExprListSyntax(
          arrayLiteral:
            LabeledExprSyntax(
              label: .predefined(.event),
              colon: .colonToken(),
              expression: DeclReferenceExprSyntax(baseName: .predefined(.event)),
              trailingComma: .commaToken()
            ),
            LabeledExprSyntax(
              label: .identifier("runtime"),
              colon: .colonToken(),
              expression: DeclReferenceExprSyntax(baseName: .identifier("runtime"))
            )
        ),
        rightParen: .rightParenToken()
      )
    )
  }

  static func emitOnInitializerExit(
    shouldMeasure: Bool,
    capturesError: Bool,
    emission: AutoLogEmissionPlan
  ) -> CodeBlockItemSyntax? {
    var statements: [String] = []
    let timingAssignment = """
    if let __logStart {
      event.duration = ContinuousClock.now - __logStart
    }
    """

    if emission.emitsSuccess, emission.emitsFailure {
      if capturesError {
        statements.append(
          """
          if let __logError {
            event.result = .failure(__logError)
          }
          """
        )
      }

      if shouldMeasure {
        statements.append(timingAssignment)
      }

      statements.append("autoLogger.emitIfEnabled(event: event, runtime: runtime)")
    }

    if capturesError, emission.emitsFailure, !emission.emitsSuccess {
      statements.append(
        """
        if let __logError {
          event.result = .failure(__logError)
        \(shouldMeasure ? timingAssignment.indentedInitializerExitBranch : "")
          autoLogger.emitIfEnabled(event: event, runtime: runtime)
        }
        """
      )
    }

    if emission.emitsSuccess, !emission.emitsFailure {
      var successStatements: [String] = []
      statements.append(
        capturesError
        ? "if __logError == nil {"
        : "do {"
      )
      if shouldMeasure {
        successStatements.append(timingAssignment)
      }
      successStatements.append("autoLogger.emitIfEnabled(event: event, runtime: runtime)")
      statements.append(
        successStatements
          .map(\.indentedInitializerExitBranch)
          .joined(separator: "\n")
      )
      statements.append("}")
    }

    guard !statements.isEmpty else { return nil }

    let body = statements
      .map { statement in
        statement
          .split(separator: "\n", omittingEmptySubsequences: false)
          .map { "  \($0)" }
          .joined(separator: "\n")
      }
      .joined(separator: "\n")

    return CodeBlockItemSyntax(stringLiteral: "defer {\n\(body)\n}")
  }

  /// Generates: `event.isMeasuredExplicitly = true`
  ///
  /// Injected when `@Log(measure: true)` is used, so the formatter shows timing
  /// even when the runtime configuration has timing disabled by default.
  static func captureExplicitMeasure() -> CodeBlockItemSyntax {
    return CodeBlockItemSyntax(
      InfixOperatorExprSyntax(
        leftOperand: MemberAccessExprSyntax(
          base: DeclReferenceExprSyntax(baseName: .predefined(.event)),
          period: .periodToken(),
          name: .predefined(.isMeasuredExplicitly)
        ),
        operator: AssignmentExprSyntax(),
        rightOperand: BooleanLiteralExprSyntax(booleanLiteral: true)
      )
    )
  }

  /// Generates a runtime-aware optional timing start.
  static func captureTimingStart() -> CodeBlockItemSyntax {
    CodeBlockItemSyntax(
      VariableDeclSyntax(
        bindingSpecifier: .keyword(.let),
        bindings: PatternBindingListSyntax(
          arrayLiteral: PatternBindingSyntax(
            pattern: IdentifierPatternSyntax(identifier: .predefined(.__logStart)),
            initializer: InitializerClauseSyntax(
              value: TernaryExprSyntax(
                condition: FunctionCallExprSyntax(
                  calledExpression: MemberAccessExprSyntax(
                    base: DeclReferenceExprSyntax(baseName: .predefined(.autoLogger)),
                    period: .periodToken(),
                    name: .identifier("shouldMeasureTiming")
                  ),
                  leftParen: .leftParenToken(),
                  arguments: LabeledExprListSyntax(
                    arrayLiteral:
                      LabeledExprSyntax(
                        label: .identifier("for"),
                        colon: .colonToken(),
                        expression: DeclReferenceExprSyntax(baseName: .predefined(.event)),
                        trailingComma: .commaToken()
                      ),
                      LabeledExprSyntax(
                        label: .identifier("runtime"),
                        colon: .colonToken(),
                        expression: DeclReferenceExprSyntax(baseName: .identifier("runtime"))
                      )
                  ),
                  rightParen: .rightParenToken()
                ),
                questionMark: .postfixQuestionMarkToken(
                  leadingTrivia: .space,
                  trailingTrivia: .space
                ),
                thenExpression: MemberAccessExprSyntax(
                  base: DeclReferenceExprSyntax(baseName: .predefined(.ContinuousClock)),
                  period: .periodToken(),
                  name: .predefined(.now)
                ),
                colon: .colonToken(
                  leadingTrivia: .space,
                  trailingTrivia: .space
                ),
                elseExpression: NilLiteralExprSyntax(nilKeyword: .keyword(.nil))
              )
            )
          )
        )
      )
    )
  }

  /// Generates a duration assignment when timing was enabled at function entry.
  static func captureTimingEnd() -> CodeBlockItemSyntax {
    CodeBlockItemSyntax(
      IfExprSyntax(
        conditions: ConditionElementListSyntax {
          ConditionElementSyntax(
            condition: .optionalBinding(
              OptionalBindingConditionSyntax(
                bindingSpecifier: .keyword(.let),
                pattern: IdentifierPatternSyntax(identifier: .predefined(.__logStart))
              )
            )
          )
        },
        body: CodeBlockSyntax(
          statements: CodeBlockItemListSyntax {
            CodeBlockItemSyntax(
              InfixOperatorExprSyntax(
                leftOperand: MemberAccessExprSyntax(
                  base: DeclReferenceExprSyntax(baseName: .predefined(.event)),
                  period: .periodToken(),
                  name: .predefined(.duration)
                ),
                operator: AssignmentExprSyntax(),
                rightOperand: InfixOperatorExprSyntax(
                  leftOperand: MemberAccessExprSyntax(
                    base: DeclReferenceExprSyntax(baseName: .predefined(.ContinuousClock)),
                    period: .periodToken(),
                    name: .predefined(.now)
                  ),
                  operator: BinaryOperatorExprSyntax(operator: .binaryOperator("-")),
                  rightOperand: DeclReferenceExprSyntax(baseName: .predefined(.__logStart))
                )
              )
            )
          }
        )
      )
    )
  }

  static func recordHandledError() -> CodeBlockItemSyntax {
    CodeBlockItemSyntax(
      FunctionCallExprSyntax(
        calledExpression: MemberAccessExprSyntax(
          base: DeclReferenceExprSyntax(baseName: .predefined(.event)),
          period: .periodToken(),
          name: .identifier("recordHandledError")
        ),
        leftParen: .leftParenToken(),
        arguments: LabeledExprListSyntax(),
        rightParen: .rightParenToken()
      )
    )
  }

  static func emitHandledError(
    errorExpression: ExprSyntax?
  ) -> CodeBlockItemSyntax {
    let calledExpression = MemberAccessExprSyntax(
      base: DeclReferenceExprSyntax(baseName: .predefined(.autoLogger)),
      period: .periodToken(),
      name: .identifier("emitHandledErrorIfEnabled")
    )

    let arguments = if let errorExpression {
      LabeledExprListSyntax {
        LabeledExprSyntax(
          label: .identifier("error"),
          colon: .colonToken(),
          expression: errorExpression,
          trailingComma: .commaToken()
        )
        LabeledExprSyntax(
          label: .identifier("from"),
          colon: .colonToken(),
          expression: DeclReferenceExprSyntax(baseName: .predefined(.event)),
          trailingComma: .commaToken()
        )
        LabeledExprSyntax(
          label: .identifier("runtime"),
          colon: .colonToken(),
          expression: DeclReferenceExprSyntax(baseName: .identifier("runtime"))
        )
      }
    } else {
      LabeledExprListSyntax {
        LabeledExprSyntax(
          label: .identifier("from"),
          colon: .colonToken(),
          expression: DeclReferenceExprSyntax(baseName: .predefined(.event)),
          trailingComma: .commaToken()
        )
        LabeledExprSyntax(
          label: .identifier("runtime"),
          colon: .colonToken(),
          expression: DeclReferenceExprSyntax(baseName: .identifier("runtime"))
        )
      }
    }

    return CodeBlockItemSyntax(
      FunctionCallExprSyntax(
        calledExpression: calledExpression,
        leftParen: .leftParenToken(),
        arguments: arguments,
        rightParen: .rightParenToken()
      )
    )
  }

  static func instrumentedBody(
    of function: FunctionSyntax,
    capturesHandledErrors: Bool = true
  ) -> [CodeBlockItemSyntax] {
    guard let body = function.syntax.body else { return function.body }
    var yieldCaptureIndex = 0
    var conditionTraceIndex = 0
    return rewriteStatements(
      Array(body.statements),
      yieldCaptureIndex: &yieldCaptureIndex,
      conditionTraceIndex: &conditionTraceIndex,
      capturesHandledErrors: capturesHandledErrors
    )
  }

  static func instrumentedPlain(
    of function: FunctionSyntax,
    capturesHandledErrors: Bool = true
  ) -> FunctionDeclSyntax {
    var plain = function.plain
    guard var body = plain.body else { return plain }
    var yieldCaptureIndex = 0
    var conditionTraceIndex = 0
    body.statements = CodeBlockItemListSyntax(
      rewriteStatements(
        Array(body.statements),
        yieldCaptureIndex: &yieldCaptureIndex,
        conditionTraceIndex: &conditionTraceIndex,
        capturesHandledErrors: capturesHandledErrors
      )
    )
    plain.body = body
    return plain
  }

  static func instrumentedBody(
    of initializer: InitializerSyntax,
    capturesHandledErrors: Bool = true
  ) -> [CodeBlockItemSyntax] {
    guard let body = initializer.syntax.body else { return initializer.body }
    var yieldCaptureIndex = 0
    var conditionTraceIndex = 0
    return rewriteStatements(
      Array(body.statements),
      yieldCaptureIndex: &yieldCaptureIndex,
      conditionTraceIndex: &conditionTraceIndex,
      capturesHandledErrors: capturesHandledErrors
    )
  }

  static func throwingInitializerBody(
    of initializer: InitializerSyntax,
    capturesHandledErrors: Bool = true
  ) -> CodeBlockItemSyntax {
    CodeBlockItemSyntax(
      DoStmtSyntax(
        body: CodeBlockSyntax(
          statements: CodeBlockItemListSyntax(
            self.instrumentedBody(
              of: initializer,
              capturesHandledErrors: capturesHandledErrors
            )
          )
        ),
        catchClauses: CatchClauseListSyntax(
          arrayLiteral: CatchClauseSyntax(
            body: CodeBlockSyntax(
              statements: CodeBlockItemListSyntax {
                CodeBlockItemSyntax(stringLiteral: "__logError = error")
                CodeBlockItemSyntax.rethrow
              }
            )
          )
        )
      )
    )
  }

  static func rewriteStatements(
    _ statements: [CodeBlockItemSyntax],
    yieldCaptureIndex: inout Int,
    conditionTraceIndex: inout Int,
    earlyExitContext: EarlyExitContext? = nil,
    capturesHandledErrors: Bool = true
  ) -> [CodeBlockItemSyntax] {
    var sawExplicitEarlyExit = false
    var rewritten: [CodeBlockItemSyntax] = []

    for statement in statements {
      rewritten.append(
        contentsOf: rewriteStatementItem(
          statement,
          yieldCaptureIndex: &yieldCaptureIndex,
          conditionTraceIndex: &conditionTraceIndex,
          earlyExitContext: earlyExitContext,
          capturesHandledErrors: capturesHandledErrors,
          sawExplicitEarlyExit: &sawExplicitEarlyExit
        )
      )
    }

    return rewritten
  }

  static func rewriteStatementItem(
    _ item: CodeBlockItemSyntax,
    yieldCaptureIndex: inout Int,
    conditionTraceIndex: inout Int,
    earlyExitContext: EarlyExitContext? = nil,
    capturesHandledErrors: Bool = true,
    sawExplicitEarlyExit: inout Bool
  ) -> [CodeBlockItemSyntax] {
    if case let .expr(expression) = item.item,
       let call = expression.as(FunctionCallExprSyntax.self),
       isExplicitEarlyExitCall(call)
    {
      sawExplicitEarlyExit = true
      guard let earlyExitContext else { return [item] }
      return [captureEarlyExit(earlyExitContext, explicitCall: call)]
    }

    guard case let .stmt(statement) = item.item else {
      return [item]
    }

    if let call = explicitEarlyExitCall(in: statement) {
      sawExplicitEarlyExit = true
      guard let earlyExitContext else { return [item] }
      return [captureEarlyExit(earlyExitContext, explicitCall: call)]
    }

    if let expanded = rewriteEarlyExitStatement(
      statement,
      earlyExitContext: earlyExitContext,
      sawExplicitEarlyExit: sawExplicitEarlyExit
    ) {
      return expanded
    }

    if let expanded = rewriteYieldStatement(
      statement,
      yieldCaptureIndex: &yieldCaptureIndex
    ) {
      return expanded
    }

    if var expressionStmt = statement.as(ExpressionStmtSyntax.self) {
      expressionStmt.expression = rewriteExpression(
        expressionStmt.expression,
        yieldCaptureIndex: &yieldCaptureIndex,
        conditionTraceIndex: &conditionTraceIndex,
        earlyExitContext: earlyExitContext,
        capturesHandledErrors: capturesHandledErrors
      )
      return [CodeBlockItemSyntax(expressionStmt)]
    }

    if var forStmt = statement.as(ForStmtSyntax.self) {
      forStmt.body.statements = CodeBlockItemListSyntax(
        rewriteStatements(
          Array(forStmt.body.statements),
          yieldCaptureIndex: &yieldCaptureIndex,
          conditionTraceIndex: &conditionTraceIndex,
          earlyExitContext: earlyExitContext,
          capturesHandledErrors: capturesHandledErrors
        )
      )
      return [CodeBlockItemSyntax(forStmt)]
    }

    if var whileStmt = statement.as(WhileStmtSyntax.self) {
      whileStmt.body.statements = CodeBlockItemListSyntax(
        rewriteStatements(
          Array(whileStmt.body.statements),
          yieldCaptureIndex: &yieldCaptureIndex,
          conditionTraceIndex: &conditionTraceIndex,
          earlyExitContext: earlyExitContext,
          capturesHandledErrors: capturesHandledErrors
        )
      )
      return [CodeBlockItemSyntax(whileStmt)]
    }

    if var repeatStmt = statement.as(RepeatStmtSyntax.self) {
      repeatStmt.body.statements = CodeBlockItemListSyntax(
        rewriteStatements(
          Array(repeatStmt.body.statements),
          yieldCaptureIndex: &yieldCaptureIndex,
          conditionTraceIndex: &conditionTraceIndex,
          earlyExitContext: earlyExitContext,
          capturesHandledErrors: capturesHandledErrors
        )
      )
      return [CodeBlockItemSyntax(repeatStmt)]
    }

    if var guardStmt = statement.as(GuardStmtSyntax.self) {
      let guardCondition = guardStmt.conditions.trimmedDescription
      let tracePlan = conditionTracePlan(
        for: guardStmt.conditions,
        variableName: "__logCondition\(conditionTraceIndex)"
      )
      if tracePlan != nil {
        conditionTraceIndex += 1
      }

      let guardFailureContext = EarlyExitContext(
        kind: .guard,
        branchCondition: guardCondition,
        effectiveCondition: negateConditionString(guardCondition),
        branchConditionExpression: tracePlan?.passingDescriptionExpression,
        effectiveConditionExpression: tracePlan?.failingDescriptionExpression
      )
      if let tracePlan {
        guardStmt.conditions = tracePlan.passedCondition
      }
      guardStmt.body.statements = CodeBlockItemListSyntax(
        rewriteStatements(
          Array(guardStmt.body.statements),
          yieldCaptureIndex: &yieldCaptureIndex,
          conditionTraceIndex: &conditionTraceIndex,
          earlyExitContext: guardFailureContext,
          capturesHandledErrors: capturesHandledErrors
        )
      )
      if let tracePlan {
        return [tracePlan.declaration, CodeBlockItemSyntax(guardStmt.trimmed)]
      }
      return [CodeBlockItemSyntax(guardStmt)]
    }

    if var doStmt = statement.as(DoStmtSyntax.self) {
      doStmt.body.statements = CodeBlockItemListSyntax(
        rewriteStatements(
          Array(doStmt.body.statements),
          yieldCaptureIndex: &yieldCaptureIndex,
          conditionTraceIndex: &conditionTraceIndex,
          earlyExitContext: earlyExitContext,
          capturesHandledErrors: capturesHandledErrors
        )
      )

      var catchClauses = doStmt.catchClauses
      for index in catchClauses.indices {
        var clause = catchClauses[index]
        let rewrittenStatements = rewriteStatements(
          Array(clause.body.statements),
          yieldCaptureIndex: &yieldCaptureIndex,
          conditionTraceIndex: &conditionTraceIndex,
          earlyExitContext: earlyExitContext,
          capturesHandledErrors: capturesHandledErrors
        )
        let errorExpression = catchErrorExpression(in: clause)
        clause.body.statements = CodeBlockItemListSyntax(
          (capturesHandledErrors
            ? [recordHandledError(), emitHandledError(errorExpression: errorExpression)]
            : [])
            + rewrittenStatements
        )
        catchClauses[index] = clause
      }
      doStmt.catchClauses = catchClauses
      return [CodeBlockItemSyntax(doStmt)]
    }

    return [item]
  }

  static func rewriteExpression(
    _ expression: ExprSyntax,
    yieldCaptureIndex: inout Int,
    conditionTraceIndex: inout Int,
    earlyExitContext: EarlyExitContext? = nil,
    capturesHandledErrors: Bool = true,
    isElseIfBranch: Bool = false,
    priorFalseConditions: [String] = []
  ) -> ExprSyntax {
    if var closure = expression.as(ClosureExprSyntax.self) {
      closure.statements = CodeBlockItemListSyntax(
        rewriteStatements(
          Array(closure.statements),
          yieldCaptureIndex: &yieldCaptureIndex,
          conditionTraceIndex: &conditionTraceIndex,
          capturesHandledErrors: capturesHandledErrors
        )
      )
      return ExprSyntax(closure)
    }

    if var functionCall = expression.as(FunctionCallExprSyntax.self) {
      functionCall.calledExpression = rewriteExpression(
        functionCall.calledExpression,
        yieldCaptureIndex: &yieldCaptureIndex,
        conditionTraceIndex: &conditionTraceIndex,
        earlyExitContext: earlyExitContext,
        capturesHandledErrors: capturesHandledErrors
      )

      var arguments = functionCall.arguments
      for index in arguments.indices {
        var argument = arguments[index]
        argument.expression = rewriteExpression(
          argument.expression,
          yieldCaptureIndex: &yieldCaptureIndex,
          conditionTraceIndex: &conditionTraceIndex,
          earlyExitContext: earlyExitContext,
          capturesHandledErrors: capturesHandledErrors
        )
        arguments[index] = argument
      }
      functionCall.arguments = arguments

      if var trailingClosure = functionCall.trailingClosure {
        trailingClosure.statements = CodeBlockItemListSyntax(
          rewriteStatements(
            Array(trailingClosure.statements),
            yieldCaptureIndex: &yieldCaptureIndex,
            conditionTraceIndex: &conditionTraceIndex,
            capturesHandledErrors: capturesHandledErrors
          )
        )
        functionCall.trailingClosure = trailingClosure
      }

      var additional = functionCall.additionalTrailingClosures
      for index in additional.indices {
        var closureElement = additional[index]
        var closure = closureElement.closure
        closure.statements = CodeBlockItemListSyntax(
          rewriteStatements(
            Array(closure.statements),
            yieldCaptureIndex: &yieldCaptureIndex,
            conditionTraceIndex: &conditionTraceIndex,
            capturesHandledErrors: capturesHandledErrors
          )
        )
        closureElement.closure = closure
        additional[index] = closureElement
      }
      functionCall.additionalTrailingClosures = additional

      return ExprSyntax(functionCall)
    }

    if var switchExpr = expression.as(SwitchExprSyntax.self) {
      switchExpr.subject = rewriteExpression(
        switchExpr.subject,
        yieldCaptureIndex: &yieldCaptureIndex,
        conditionTraceIndex: &conditionTraceIndex,
        earlyExitContext: earlyExitContext,
        capturesHandledErrors: capturesHandledErrors
      )

      var cases = switchExpr.cases
      for index in cases.indices {
        guard var switchCase = cases[index].as(SwitchCaseSyntax.self) else { continue }
        let context = switchEarlyExitContext(
          for: switchCase,
          subject: switchExpr.subject
        )
        switchCase.statements = CodeBlockItemListSyntax(
          rewriteConditionalBranchStatements(
            Array(switchCase.statements),
            yieldCaptureIndex: &yieldCaptureIndex,
            conditionTraceIndex: &conditionTraceIndex,
            earlyExitContext: context,
            capturesHandledErrors: capturesHandledErrors
          )
        )
        cases[index] = SwitchCaseListSyntax.Element(switchCase)
      }
      switchExpr.cases = cases

      return ExprSyntax(switchExpr)
    }

    if var ifExpr = expression.as(IfExprSyntax.self) {
      let condition = ifExpr.conditions.trimmedDescription
      let failedCondition = negateConditionString(condition)
      let enteredConditions = priorFalseConditions + [condition]
      ifExpr.body.statements = CodeBlockItemListSyntax(
        rewriteConditionalBranchStatements(
          Array(ifExpr.body.statements),
          yieldCaptureIndex: &yieldCaptureIndex,
          conditionTraceIndex: &conditionTraceIndex,
          earlyExitContext: EarlyExitContext(
            kind: isElseIfBranch ? .elseif : .if,
            branchCondition: condition,
            effectiveCondition: joinedConditionString(enteredConditions)
          ),
          capturesHandledErrors: capturesHandledErrors
        )
      )

      if let elseBody = ifExpr.elseBody {
        switch elseBody {
        case .codeBlock(var codeBlock):
          codeBlock.statements = CodeBlockItemListSyntax(
            rewriteConditionalBranchStatements(
              Array(codeBlock.statements),
              yieldCaptureIndex: &yieldCaptureIndex,
              conditionTraceIndex: &conditionTraceIndex,
              earlyExitContext: EarlyExitContext(
                kind: .else,
                branchCondition: condition,
                effectiveCondition: joinedConditionString(priorFalseConditions + [failedCondition])
              ),
              capturesHandledErrors: capturesHandledErrors
            )
          )
          ifExpr.elseBody = .codeBlock(codeBlock)

        case .ifExpr(let nestedIf):
          let rewrittenNested = rewriteExpression(
            ExprSyntax(nestedIf),
            yieldCaptureIndex: &yieldCaptureIndex,
            conditionTraceIndex: &conditionTraceIndex,
            earlyExitContext: earlyExitContext,
            capturesHandledErrors: capturesHandledErrors,
            isElseIfBranch: true,
            priorFalseConditions: priorFalseConditions + [failedCondition]
          )
          if let nestedIfExpr = rewrittenNested.as(IfExprSyntax.self) {
            ifExpr.elseBody = .ifExpr(nestedIfExpr)
          }
        }
      }

      return ExprSyntax(ifExpr)
    }

    return expression
  }

  static func rewriteConditionalBranchStatements(
    _ statements: [CodeBlockItemSyntax],
    yieldCaptureIndex: inout Int,
    conditionTraceIndex: inout Int,
    earlyExitContext: EarlyExitContext,
    capturesHandledErrors: Bool = true
  ) -> [CodeBlockItemSyntax] {
    [
      captureBranchDecision(earlyExitContext),
    ] + rewriteStatements(
      statements,
      yieldCaptureIndex: &yieldCaptureIndex,
      conditionTraceIndex: &conditionTraceIndex,
      earlyExitContext: earlyExitContext,
      capturesHandledErrors: capturesHandledErrors
    )
  }

  static func rewriteYieldStatement(
    _ statement: StmtSyntax,
    yieldCaptureIndex: inout Int
  ) -> [CodeBlockItemSyntax]? {
    guard
      let expressionStmt = statement.as(ExpressionStmtSyntax.self),
      let call = expressionStmt.expression.as(FunctionCallExprSyntax.self),
      isYieldCall(call),
      let firstArgument = call.arguments.first
    else { return nil }

    let tempName = TokenSyntax.identifier("__logYieldValue\(yieldCaptureIndex)")
    yieldCaptureIndex += 1

    let captureValue = CodeBlockItemSyntax(
      VariableDeclSyntax(
        bindingSpecifier: .keyword(.let),
        bindings: PatternBindingListSyntax(
          arrayLiteral: PatternBindingSyntax(
            pattern: IdentifierPatternSyntax(identifier: tempName),
            initializer: InitializerClauseSyntax(value: firstArgument.expression)
          )
        )
      )
    )

    let describeValueExpr = FunctionCallExprSyntax(
      calledExpression: DeclReferenceExprSyntax(baseName: .identifier("String")),
      leftParen: .leftParenToken(),
      arguments: LabeledExprListSyntax(
        arrayLiteral: LabeledExprSyntax(
          label: .identifier("describing"),
          colon: .colonToken(),
          expression: DeclReferenceExprSyntax(baseName: tempName)
        )
      ),
      rightParen: .rightParenToken()
    )

    let messageExpr = InfixOperatorExprSyntax(
      leftOperand: StringLiteralExprSyntax(content: "[AsyncStream.yield] value="),
      operator: BinaryOperatorExprSyntax(operator: .binaryOperator("+")),
      rightOperand: describeValueExpr
    )

    let emitUpdate = CodeBlockItemSyntax(
      FunctionCallExprSyntax(
        calledExpression: MemberAccessExprSyntax(
          base: DeclReferenceExprSyntax(baseName: .predefined(.AutoLogSource)),
          period: .periodToken(),
          name: .predefined(.emit)
        ),
        leftParen: .leftParenToken(),
        arguments: LabeledExprListSyntax {
          LabeledExprSyntax(
            expression: MemberAccessExprSyntax(
              period: .periodToken(),
              name: .identifier("update")
            ),
            trailingComma: .commaToken()
          )
          LabeledExprSyntax(expression: messageExpr)
        },
        rightParen: .rightParenToken()
      )
    )

    var rewrittenCall = call
    var rewrittenArguments = rewrittenCall.arguments
    let firstIndex = rewrittenArguments.startIndex
    var updatedArgument = rewrittenArguments[firstIndex]
    updatedArgument.expression = ExprSyntax(DeclReferenceExprSyntax(baseName: tempName))
    rewrittenArguments[firstIndex] = updatedArgument
    rewrittenCall.arguments = rewrittenArguments

    let callYield = CodeBlockItemSyntax(rewrittenCall)
    return [captureValue, emitUpdate, callYield]
  }

  static func rewriteEarlyExitStatement(
    _ statement: StmtSyntax,
    earlyExitContext: EarlyExitContext?,
    sawExplicitEarlyExit: Bool
  ) -> [CodeBlockItemSyntax]? {
    guard let earlyExitContext else { return nil }
    guard !sawExplicitEarlyExit else { return nil }

    if let returnStmt = statement.as(ReturnStmtSyntax.self) {
      return [
        captureEarlyExit(earlyExitContext),
        CodeBlockItemSyntax(returnStmt.trimmed),
      ]
    }

    if let throwStmt = statement.as(ThrowStmtSyntax.self) {
      return [
        captureEarlyExit(earlyExitContext),
        CodeBlockItemSyntax(throwStmt.trimmed),
      ]
    }

    return nil
  }

  static func captureEarlyExit(
    _ context: EarlyExitContext,
    explicitCall: FunctionCallExprSyntax? = nil
  ) -> CodeBlockItemSyntax {
    let explicitArguments = explicitEarlyExitArguments(from: explicitCall)
    let intentExpression = explicitArguments.intent
      ?? ExprSyntax(MemberAccessExprSyntax(period: .periodToken(), name: .identifier("unknown")))
    let messageExpression = explicitArguments.message
      ?? (explicitArguments.shouldDefaultMessageToUnknown
        ? ExprSyntax(StringLiteralExprSyntax(content: "unknown"))
        : ExprSyntax(NilLiteralExprSyntax(nilKeyword: .keyword(.nil))))
    let conditionExpression: ExprSyntax = context.effectiveConditionExpression ?? context.effectiveCondition.map {
      ExprSyntax(StringLiteralExprSyntax(content: $0))
    } ?? ExprSyntax(NilLiteralExprSyntax(nilKeyword: .keyword(.nil)))

    return CodeBlockItemSyntax(
      InfixOperatorExprSyntax(
        leftOperand: MemberAccessExprSyntax(
          base: DeclReferenceExprSyntax(baseName: .predefined(.event)),
          period: .periodToken(),
          name: .identifier("earlyExit")
        ),
        operator: AssignmentExprSyntax(),
        rightOperand: FunctionCallExprSyntax(
          calledExpression: DeclReferenceExprSyntax(
            baseName: .identifier("AutoLogEarlyExit")
          ),
          leftParen: .leftParenToken(),
          arguments: LabeledExprListSyntax {
            LabeledExprSyntax(
              label: .identifier("kind"),
              colon: .colonToken(),
              expression: branchKindExpression(context.kind),
              trailingComma: .commaToken()
            )
            LabeledExprSyntax(
              label: .identifier("intent"),
              colon: .colonToken(),
              expression: intentExpression,
              trailingComma: .commaToken()
            )
            LabeledExprSyntax(
              label: .identifier("condition"),
              colon: .colonToken(),
              expression: conditionExpression,
              trailingComma: .commaToken()
            )
            LabeledExprSyntax(
              label: .identifier("message"),
              colon: .colonToken(),
              expression: messageExpression
            )
          },
          rightParen: .rightParenToken()
        )
      )
    )
  }

  static func captureBranchDecision(
    _ context: EarlyExitContext
  ) -> CodeBlockItemSyntax {
    let conditionExpression: ExprSyntax = context.branchConditionExpression ?? context.branchCondition.map {
      ExprSyntax(StringLiteralExprSyntax(content: $0))
    } ?? ExprSyntax(NilLiteralExprSyntax(nilKeyword: .keyword(.nil)))

    return CodeBlockItemSyntax(
      FunctionCallExprSyntax(
        calledExpression: MemberAccessExprSyntax(
          base: DeclReferenceExprSyntax(baseName: .predefined(.event)),
          period: .periodToken(),
          name: .identifier("recordBranchDecision")
        ),
        leftParen: .leftParenToken(),
        arguments: LabeledExprListSyntax {
          LabeledExprSyntax(
            label: .identifier("kind"),
            colon: .colonToken(),
            expression: branchKindExpression(context.kind),
            trailingComma: .commaToken()
          )
          LabeledExprSyntax(
            label: .identifier("condition"),
            colon: .colonToken(),
            expression: conditionExpression
          )
        },
        rightParen: .rightParenToken()
      )
    )
  }

  static func branchKindExpression(_ kind: EarlyExitContext.Kind) -> ExprSyntax {
    let kindName: String
    switch kind {
    case .guard:
      kindName = "guard"
    case .if:
      kindName = "if"
    case .elseif:
      kindName = "elseif"
    case .else:
      kindName = "else"
    case .switchCase:
      kindName = "switchCase"
    case .switchDefault:
      kindName = "switchDefault"
    }

    return ExprSyntax(
      MemberAccessExprSyntax(
        base: MemberAccessExprSyntax(
          base: DeclReferenceExprSyntax(baseName: .identifier("AutoLogEarlyExit")),
          period: .periodToken(),
          name: .identifier("Kind")
        ),
        period: .periodToken(),
        name: .identifier(kindName)
      )
    )
  }

  static func joinedConditionString(_ conditions: [String]) -> String? {
    let normalized = conditions
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }

    guard !normalized.isEmpty else { return nil }
    return normalized.joined(separator: ", ")
  }

  static func conditionTracePlan(
    for conditions: ConditionElementListSyntax,
    variableName: String
  ) -> AutoLogConditionTracePlan? {
    let elements = Array(conditions)
    guard elements.count == 1,
          let first = elements.first,
          case .expression = first.condition else {
      return nil
    }

    let originalCondition = conditions.trimmedDescription
    guard !originalCondition.contains(" try "),
          !originalCondition.hasPrefix("try "),
          !originalCondition.contains(" await "),
          !originalCondition.hasPrefix("await "),
          let components = booleanConditionComponents(from: originalCondition) else {
      return nil
    }
    guard !components.operators.isEmpty else { return nil }

    let tracedCondition = components.terms.enumerated().map { index, term in
      let expression = "\(variableName).term(\"\(AutoLogConditionTracePlan.escaped(term))\", \(term))"
      guard index > 0 else { return expression }
      return "\(components.operators[index - 1]) \(expression)"
    }.joined(separator: " ")

    return AutoLogConditionTracePlan(
      variableName: variableName,
      originalCondition: originalCondition,
      tracedConditionExpression: tracedCondition
    )
  }

  static func booleanConditionComponents(
    from condition: String
  ) -> (terms: [String], operators: [String])? {
    var terms: [String] = []
    var operators: [String] = []
    var current = ""
    var depth = 0
    var inString = false
    var isEscaped = false
    var index = condition.startIndex

    func appendCurrentTerm() {
      let term = current.trimmingCharacters(in: .whitespacesAndNewlines)
      if !term.isEmpty {
        terms.append(term)
      }
      current = ""
    }

    while index < condition.endIndex {
      let character = condition[index]

      if inString {
        current.append(character)
        if isEscaped {
          isEscaped = false
        } else if character == "\\" {
          isEscaped = true
        } else if character == "\"" {
          inString = false
        }
        index = condition.index(after: index)
        continue
      }

      if character == "\"" {
        inString = true
        current.append(character)
        index = condition.index(after: index)
        continue
      }

      switch character {
      case "(", "[", "{":
        depth += 1
      case ")", "]", "}":
        depth = max(0, depth - 1)
      default:
        break
      }

      if depth == 0 {
        let next = condition.index(after: index)
        if next < condition.endIndex {
          let pair = String(condition[index...next])
          if pair == "&&" || pair == "||" {
            appendCurrentTerm()
            operators.append(pair)
            index = condition.index(after: next)
            continue
          }
        }
      }

      current.append(character)
      index = condition.index(after: index)
    }

    appendCurrentTerm()
    guard !terms.isEmpty, operators.count == terms.count - 1 else { return nil }
    return (terms, operators)
  }

  static func negateConditionString(_ condition: String) -> String {
    let trimmed = condition.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "!" }

    if let inverted = unwrapNegatedCondition(trimmed) {
      return inverted
    }

    if shouldWrapNegatedCondition(trimmed) {
      return "!(\(trimmed))"
    }

    return "!\(trimmed)"
  }

  static func unwrapNegatedCondition(_ condition: String) -> String? {
    guard condition.hasPrefix("!") else { return nil }

    let remainder = String(condition.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
    guard !remainder.isEmpty else { return nil }

    if remainder.hasPrefix("("), remainder.hasSuffix(")") {
      let inner = remainder.dropFirst().dropLast().trimmingCharacters(in: .whitespacesAndNewlines)
      return inner.isEmpty ? nil : inner
    }

    return remainder
  }

  static func shouldWrapNegatedCondition(_ condition: String) -> Bool {
    condition.contains(" ") || condition.contains("&&") || condition.contains("||")
  }

  static func explicitEarlyExitCall(in statement: StmtSyntax) -> FunctionCallExprSyntax? {
    guard
      let expressionStmt = statement.as(ExpressionStmtSyntax.self),
      let call = expressionStmt.expression.as(FunctionCallExprSyntax.self),
      isExplicitEarlyExitCall(call)
    else { return nil }

    return call
  }

  static func isExplicitEarlyExitCall(_ call: FunctionCallExprSyntax) -> Bool {
    guard let member = call.calledExpression.as(MemberAccessExprSyntax.self) else {
      return false
    }

    guard member.declName.baseName.text == "earlyExit" else {
      return false
    }

    let base = member.base?.trimmedDescription
    return base == "AutoLog" || base == "AutoLogSource"
  }

  static func explicitEarlyExitArguments(
    from call: FunctionCallExprSyntax?
  ) -> (intent: ExprSyntax?, message: ExprSyntax?, shouldDefaultMessageToUnknown: Bool) {
    guard let call else {
      return (nil, nil, false)
    }

    let arguments = Array(call.arguments)
    let intent = arguments.first?.expression
    let message = arguments.count > 1 ? arguments[1].expression : nil
    let shouldDefaultMessageToUnknown = arguments.isEmpty
    return (intent, message, shouldDefaultMessageToUnknown)
  }

  static func isYieldCall(_ call: FunctionCallExprSyntax) -> Bool {
    memberName(in: call.calledExpression) == "yield"
  }

  static func memberName(in expression: ExprSyntax) -> String? {
    if let member = expression.as(MemberAccessExprSyntax.self) {
      return member.declName.baseName.text
    }

    if let optional = expression.as(OptionalChainingExprSyntax.self) {
      return memberName(in: optional.expression)
    }

    if let forced = expression.as(ForceUnwrapExprSyntax.self) {
      return memberName(in: forced.expression)
    }

    return nil
  }

  static func catchErrorExpression(in clause: CatchClauseSyntax) -> ExprSyntax? {
    guard let firstItem = clause.catchItems.first else {
      return ExprSyntax(DeclReferenceExprSyntax(baseName: .predefined(.error)))
    }

    guard let pattern = firstItem.pattern else { return nil }
    let text = pattern.trimmedDescription
    let identifier = leadingCatchIdentifier(in: text)
    return identifier.map {
      ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier($0)))
    }
  }

  static func leadingCatchIdentifier(in pattern: String) -> String? {
    let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let words = trimmed.split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "_" })
      .map(String.init)
    guard let first = words.first else { return nil }

    if first == "let" || first == "var" {
      return words.dropFirst().first
    }

    guard first.first?.isLowercase == true || first.first == "_" else { return nil }
    guard trimmed.first?.isLetter == true else { return nil }
    if words.count >= 3, words[1] == "as" {
      return first
    }
    guard trimmed.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else { return nil }

    return first == "_" ? nil : first
  }

  static func switchEarlyExitContext(
    for switchCase: SwitchCaseSyntax,
    subject: ExprSyntax
  ) -> EarlyExitContext {
    let subjectText = subject.trimmedDescription
    let labelText: String
    let kind: EarlyExitContext.Kind

    switch switchCase.label {
    case .case(let label):
      kind = .switchCase
      labelText = label.caseItems.trimmedDescription
    case .default:
      kind = .switchDefault
      labelText = "default"
    }

    let condition = "switch \(subjectText): \(labelText)"
    return EarlyExitContext(
      kind: kind,
      branchCondition: condition,
      effectiveCondition: condition
    )
  }
}
