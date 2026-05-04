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
  }

  let kind: Kind
  let branchCondition: String?
  let effectiveCondition: String?
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
    guard let function = FunctionSyntax(from: declaration)
    else { return self.body() }
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

    let tagTraits = function.syntax.attributes.extractTagTraitsInSourceOrder()
    let omitTraits = function.syntax.attributes.extractTraits(for: .omit)
    let levelTrait = function.syntax.attributes.extractTraits(for: .level).first
    let deduplicationTrait = function.syntax.attributes.extractTraits(for: .deduplicate).first
    let resultFilterTrait = function.syntax.attributes.extractTraits(for: .when).first
    let omitRuleTraits = function.syntax.attributes.extractOmitRuleTraits()
    let instrumentedPlain = self.instrumentedPlain(of: function)

    return body {
      self.captureRuntime()
      self.hook(for: node)
      self.event(
        for: node,
        in: context,
        of: function,
        levelTrait: levelTrait,
        taggableTraits: tagTraits,
        omittableTraits: omitTraits,
        deduplicationTrait: deduplicationTrait,
        omitRuleTraits: omitRuleTraits
      )

      if isMeasuredExplicitly {
        self.captureExplicitMeasure()
      }

      self.emitStart()

      if shouldMeasure {
        self.captureTimingStart()
      }

      switch function.isThrowing {
        case false where function.isVoid:
          CodeBlockItemSyntax(instrumentedPlain)
          CodeBlockItemSyntax.call(function)
          if shouldMeasure { self.captureTimingEnd() }
          self.emit()

        case true where function.isVoid:
          CodeBlockItemSyntax(instrumentedPlain)
          CodeBlockItemSyntax.try {
            CodeBlockItemSyntax.call(function)
            if shouldMeasure { self.captureTimingEnd() }
            self.emit()
          } catch: {
            self.capture(.error)
            if shouldMeasure { self.captureTimingEnd() }
            self.emit()
            CodeBlockItemSyntax.rethrow
          }

        case true:
          CodeBlockItemSyntax(instrumentedPlain)
          CodeBlockItemSyntax.try {
            CodeBlockItemSyntax.call(function)
            if !omitTraits.contains(where: \.isOmitResult) {
              self.capture(.result)
            }
            if shouldMeasure { self.captureTimingEnd() }
            self.emit(when: resultFilterTrait)
            CodeBlockItemSyntax.return
          } catch: {
            self.capture(.error)
            if shouldMeasure { self.captureTimingEnd() }
            self.emit()
            CodeBlockItemSyntax.rethrow
          }

        case false:
          CodeBlockItemSyntax(instrumentedPlain)
          CodeBlockItemSyntax.call(function)
          if !omitTraits.contains(where: \.isOmitResult) {
            self.capture(.result)
          }
          if shouldMeasure { self.captureTimingEnd() }
          self.emit(when: resultFilterTrait)
          CodeBlockItemSyntax.return
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
    in context: some MacroExpansionContext,
    of declaration: FunctionSyntax,
    levelTrait: (any ExprSyntaxProtocol)?,
    taggableTraits: [ExprSyntax],
    omittableTraits: [any ExprSyntaxProtocol],
    deduplicationTrait: (any ExprSyntaxProtocol)?,
    omitRuleTraits: [AttributeListSyntax.OmitRuleTrait]
  ) -> CodeBlockItemSyntax {
    let capturedParameters = declaration.parameters.filter { parameter in
      !omittableTraits.contains(where: { trait in trait.isOmitParameter(parameter.name) })
    }

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

                  // MARK: - location: String
                  LabeledExprSyntax(
                    leadingTrivia: .newline,
                    label: .predefined(.location),
                    colon: .colonToken(),
                    expression: self.location(
                      of: declaration,
                      in: context
                    ),
                    trailingComma: .commaToken(),
                    trailingTrivia: .newline
                  )

                  // MARK: - declaration: String
                  LabeledExprSyntax(
                    label: .predefined(.declaration),
                    colon: .colonToken(),
                    expression: StringLiteralExprSyntax(content: declaration.description),
                    trailingComma: .commaToken(),
                    trailingTrivia: .newline
                  )

                  // MARK: - parameters: [String: Any]
                  if !omittableTraits.contains(where: \.isOmitParameters) {
                    LabeledExprSyntax(
                      label: .predefined(.parameters),
                      colon: .colonToken(),
                      expression: DictionaryExprSyntax(
                        leftSquare: .leftSquareToken(
                          trailingTrivia: capturedParameters.isEmpty ? [] : .newline
                        ),
                        rightSquare: .rightSquareToken(
                          leadingTrivia: capturedParameters.isEmpty ? [] : .newline
                        )
                      ) {
                        DictionaryElementListSyntax {
                          capturedParameters.map { parameter in
                            return DictionaryElementSyntax(
                              key: StringLiteralExprSyntax(content: parameter.name.text),
                              value: DeclReferenceExprSyntax(baseName: parameter.name.trimmed),
                              trailingComma: .commaToken(
                                presence: capturedParameters.last == parameter ? .missing : .present
                              ),
                              trailingTrivia: .newline
                            )
                          }
                        }
                      },
                      trailingComma: .commaToken(),
                      trailingTrivia: .newline
                    )
                  }

                  // MARK: - Tags
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
                    trailingComma: deduplicationTrait == nil && omitRuleTraits.isEmpty ? nil : .commaToken(),
                    trailingTrivia: deduplicationTrait == nil && omitRuleTraits.isEmpty ? .newline : []
                  )

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

  static func capture(_ baseName: TokenSyntax.Predefined) -> CodeBlockItemSyntax {
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
              expression: DeclReferenceExprSyntax(baseName: baseName.identifier)
            )
          },
          rightParen: .rightParenToken()
        )
      )
    )
  }

  /// Generates:
  /// `autoLogger.emitIfEnabled(event: event, configuration: runtime.configuration, deduplicator: runtime.deduplicator)`
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
              label: .identifier("configuration"),
              colon: .colonToken(),
              expression: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: .identifier("runtime")),
                period: .periodToken(),
                name: .identifier("configuration")
              ),
              trailingComma: .commaToken()
            ),
            LabeledExprSyntax(
              label: .identifier("deduplicator"),
              colon: .colonToken(),
              expression: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: .identifier("runtime")),
                period: .periodToken(),
                name: .identifier("deduplicator")
              )
            )
        ),
        rightParen: .rightParenToken()
      )
    )
  }

  /// Generates:
  /// `autoLogger.emitStart(event: event, configuration: runtime.configuration, deduplicator: runtime.deduplicator)`
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
              label: .identifier("configuration"),
              colon: .colonToken(),
              expression: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: .identifier("runtime")),
                period: .periodToken(),
                name: .identifier("configuration")
              ),
              trailingComma: .commaToken()
            ),
            LabeledExprSyntax(
              label: .identifier("deduplicator"),
              colon: .colonToken(),
              expression: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: .identifier("runtime")),
                period: .periodToken(),
                name: .identifier("deduplicator")
              )
            )
        ),
        rightParen: .rightParenToken()
      )
    )
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

  /// Generates: `let __logStart = ContinuousClock.now`
  static func captureTimingStart() -> CodeBlockItemSyntax {
    CodeBlockItemSyntax(
      VariableDeclSyntax(
        bindingSpecifier: .keyword(.let),
        bindings: PatternBindingListSyntax(
          arrayLiteral: PatternBindingSyntax(
            pattern: IdentifierPatternSyntax(identifier: .predefined(.__logStart)),
            initializer: InitializerClauseSyntax(
              value: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: .predefined(.ContinuousClock)),
                period: .periodToken(),
                name: .predefined(.now)
              )
            )
          )
        )
      )
    )
  }

  /// Generates: `event.duration = ContinuousClock.now - __logStart`
  static func captureTimingEnd() -> CodeBlockItemSyntax {
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
    includesImplicitErrorBinding: Bool
  ) -> CodeBlockItemSyntax {
    let calledExpression = MemberAccessExprSyntax(
      base: DeclReferenceExprSyntax(baseName: .predefined(.AutoLogSource)),
      period: .periodToken(),
      name: .identifier("handledError")
    )

    let arguments = if includesImplicitErrorBinding {
      LabeledExprListSyntax {
        LabeledExprSyntax(
          expression: DeclReferenceExprSyntax(baseName: .predefined(.error)),
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
    of function: FunctionSyntax
  ) -> [CodeBlockItemSyntax] {
    guard let body = function.syntax.body else { return function.body }
    var yieldCaptureIndex = 0
    return rewriteStatements(
      Array(body.statements),
      yieldCaptureIndex: &yieldCaptureIndex
    )
  }

  static func instrumentedPlain(
    of function: FunctionSyntax
  ) -> FunctionDeclSyntax {
    var plain = function.plain
    guard var body = plain.body else { return plain }
    var yieldCaptureIndex = 0
    body.statements = CodeBlockItemListSyntax(
      rewriteStatements(
        Array(body.statements),
        yieldCaptureIndex: &yieldCaptureIndex
      )
    )
    plain.body = body
    return plain
  }

  static func rewriteStatements(
    _ statements: [CodeBlockItemSyntax],
    yieldCaptureIndex: inout Int,
    earlyExitContext: EarlyExitContext? = nil
  ) -> [CodeBlockItemSyntax] {
    var sawExplicitEarlyExit = false
    var rewritten: [CodeBlockItemSyntax] = []

    for statement in statements {
      rewritten.append(
        contentsOf: rewriteStatementItem(
          statement,
          yieldCaptureIndex: &yieldCaptureIndex,
          earlyExitContext: earlyExitContext,
          sawExplicitEarlyExit: &sawExplicitEarlyExit
        )
      )
    }

    return rewritten
  }

  static func rewriteStatementItem(
    _ item: CodeBlockItemSyntax,
    yieldCaptureIndex: inout Int,
    earlyExitContext: EarlyExitContext? = nil,
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
        earlyExitContext: earlyExitContext
      )
      return [CodeBlockItemSyntax(expressionStmt)]
    }

    if var forStmt = statement.as(ForStmtSyntax.self) {
      forStmt.body.statements = CodeBlockItemListSyntax(
        rewriteStatements(
          Array(forStmt.body.statements),
          yieldCaptureIndex: &yieldCaptureIndex,
          earlyExitContext: earlyExitContext
        )
      )
      return [CodeBlockItemSyntax(forStmt)]
    }

    if var whileStmt = statement.as(WhileStmtSyntax.self) {
      whileStmt.body.statements = CodeBlockItemListSyntax(
        rewriteStatements(
          Array(whileStmt.body.statements),
          yieldCaptureIndex: &yieldCaptureIndex,
          earlyExitContext: earlyExitContext
        )
      )
      return [CodeBlockItemSyntax(whileStmt)]
    }

    if var repeatStmt = statement.as(RepeatStmtSyntax.self) {
      repeatStmt.body.statements = CodeBlockItemListSyntax(
        rewriteStatements(
          Array(repeatStmt.body.statements),
          yieldCaptureIndex: &yieldCaptureIndex,
          earlyExitContext: earlyExitContext
        )
      )
      return [CodeBlockItemSyntax(repeatStmt)]
    }

    if var guardStmt = statement.as(GuardStmtSyntax.self) {
      let guardCondition = guardStmt.conditions.trimmedDescription
      let guardFailureContext = EarlyExitContext(
        kind: .guard,
        branchCondition: guardCondition,
        effectiveCondition: negateConditionString(guardCondition)
      )
      guardStmt.body.statements = CodeBlockItemListSyntax(
        rewriteStatements(
          Array(guardStmt.body.statements),
          yieldCaptureIndex: &yieldCaptureIndex,
          earlyExitContext: guardFailureContext
        )
      )
      return [CodeBlockItemSyntax(guardStmt)]
    }

    if var doStmt = statement.as(DoStmtSyntax.self) {
      doStmt.body.statements = CodeBlockItemListSyntax(
        rewriteStatements(
          Array(doStmt.body.statements),
          yieldCaptureIndex: &yieldCaptureIndex,
          earlyExitContext: earlyExitContext
        )
      )

      var catchClauses = doStmt.catchClauses
      for index in catchClauses.indices {
        var clause = catchClauses[index]
        let rewrittenStatements = rewriteStatements(
          Array(clause.body.statements),
          yieldCaptureIndex: &yieldCaptureIndex,
          earlyExitContext: earlyExitContext
        )
        let includesImplicitErrorBinding = clause.catchItems.isEmpty
        clause.body.statements = CodeBlockItemListSyntax(
          [recordHandledError(), emitHandledError(includesImplicitErrorBinding: includesImplicitErrorBinding)]
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
    earlyExitContext: EarlyExitContext? = nil,
    isElseIfBranch: Bool = false,
    priorFalseConditions: [String] = []
  ) -> ExprSyntax {
    if var closure = expression.as(ClosureExprSyntax.self) {
      closure.statements = CodeBlockItemListSyntax(
        rewriteStatements(
          Array(closure.statements),
          yieldCaptureIndex: &yieldCaptureIndex
        )
      )
      return ExprSyntax(closure)
    }

    if var functionCall = expression.as(FunctionCallExprSyntax.self) {
      functionCall.calledExpression = rewriteExpression(
        functionCall.calledExpression,
        yieldCaptureIndex: &yieldCaptureIndex,
        earlyExitContext: earlyExitContext
      )

      var arguments = functionCall.arguments
      for index in arguments.indices {
        var argument = arguments[index]
        argument.expression = rewriteExpression(
          argument.expression,
          yieldCaptureIndex: &yieldCaptureIndex,
          earlyExitContext: earlyExitContext
        )
        arguments[index] = argument
      }
      functionCall.arguments = arguments

      if var trailingClosure = functionCall.trailingClosure {
        trailingClosure.statements = CodeBlockItemListSyntax(
          rewriteStatements(
            Array(trailingClosure.statements),
            yieldCaptureIndex: &yieldCaptureIndex
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
            yieldCaptureIndex: &yieldCaptureIndex
          )
        )
        closureElement.closure = closure
        additional[index] = closureElement
      }
      functionCall.additionalTrailingClosures = additional

      return ExprSyntax(functionCall)
    }

    if var ifExpr = expression.as(IfExprSyntax.self) {
      let condition = ifExpr.conditions.trimmedDescription
      let failedCondition = negateConditionString(condition)
      let enteredConditions = priorFalseConditions + [condition]
      ifExpr.body.statements = CodeBlockItemListSyntax(
        rewriteConditionalBranchStatements(
          Array(ifExpr.body.statements),
          yieldCaptureIndex: &yieldCaptureIndex,
          earlyExitContext: EarlyExitContext(
            kind: isElseIfBranch ? .elseif : .if,
            branchCondition: condition,
            effectiveCondition: joinedConditionString(enteredConditions)
          )
        )
      )

      if let elseBody = ifExpr.elseBody {
        switch elseBody {
        case .codeBlock(var codeBlock):
          codeBlock.statements = CodeBlockItemListSyntax(
            rewriteConditionalBranchStatements(
              Array(codeBlock.statements),
              yieldCaptureIndex: &yieldCaptureIndex,
              earlyExitContext: EarlyExitContext(
                kind: .else,
                branchCondition: condition,
                effectiveCondition: joinedConditionString(priorFalseConditions + [failedCondition])
              )
            )
          )
          ifExpr.elseBody = .codeBlock(codeBlock)

        case .ifExpr(let nestedIf):
          let rewrittenNested = rewriteExpression(
            ExprSyntax(nestedIf),
            yieldCaptureIndex: &yieldCaptureIndex,
            earlyExitContext: earlyExitContext,
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
    earlyExitContext: EarlyExitContext
  ) -> [CodeBlockItemSyntax] {
    [
      captureBranchDecision(earlyExitContext),
    ] + rewriteStatements(
      statements,
      yieldCaptureIndex: &yieldCaptureIndex,
      earlyExitContext: earlyExitContext
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
    let conditionExpression: ExprSyntax = context.effectiveCondition.map {
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
    let conditionExpression: ExprSyntax = context.branchCondition.map {
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
}
