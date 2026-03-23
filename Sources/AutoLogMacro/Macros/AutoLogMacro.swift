import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

protocol AutoLogMacro: BodyMacro {
  static func initialize(for node: AttributeSyntax) -> ExprSyntax
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
          baseName: .predefined(.AutoLogSource)
        ),
        period: .periodToken(),
        name: .predefined(.logger)
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

    let tagTraits = function.syntax.attributes.extractTraits(for: .tag)
    let omitTraits = function.syntax.attributes.extractTraits(for: .omit)
    let levelTrait = function.syntax.attributes.extractTraits(for: .level).first

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

    let instrumentedBody = self.instrumentedBody(of: function)
    let instrumentedPlain = self.instrumentedPlain(of: function)

    return body {
      self.hook(for: node)
      self.event(
        for: node,
        in: context,
        of: function,
        levelTrait: levelTrait,
        taggableTraits: tagTraits,
        omittableTraits: omitTraits
      )

      // When @Log(measure: true), mark this event as explicitly measured.
      // The formatter uses this to override the global measureTimingDefault.
      if isMeasuredExplicitly {
        self.captureExplicitMeasure()
      }

      // Emit 🔵 start event (respects AutoLogSettingsStorage.emitStartEvents at runtime).
      self.emitStart()

      // Capture timing start (compile-time opt-out via measure: false).
      if shouldMeasure {
        self.captureTimingStart()
      }

      switch function.isThrowing {
        case false where function.isVoid:
          instrumentedBody
          if shouldMeasure { self.captureTimingEnd() }
          self.emit()

        case true where function.isVoid:
          // Fixed: now emits on success too (paired with the start event).
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
            self.capture(.result)
            if shouldMeasure { self.captureTimingEnd() }
            self.emit()
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
          self.emit()
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

  static func event(
    for node: AttributeSyntax,
    in context: some MacroExpansionContext,
    of declaration: FunctionSyntax,
    levelTrait: (any ExprSyntaxProtocol)?,
    taggableTraits: [any ExprSyntaxProtocol],
    omittableTraits: [any ExprSyntaxProtocol]
  ) -> CodeBlockItemSyntax {
    CodeBlockItemSyntax(
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
                          trailingTrivia: declaration.parameters.isEmpty ? [] : .newline
                        ),
                        rightSquare: .rightSquareToken(
                          leadingTrivia: declaration.parameters.isEmpty ? [] : .newline
                        )
                      ) {
                        DictionaryElementListSyntax {
                          declaration.parameters.compactMap { parameter in
                            // TODO: 23122K - Is there a better way to handle it?
                            if omittableTraits.contains(
                              where: { trait in trait.isOmitParameter(parameter.name) }
                            ) { return nil }

                            return DictionaryElementSyntax(
                              key: StringLiteralExprSyntax(content: parameter.name.text),
                              value: DeclReferenceExprSyntax(baseName: parameter.name.trimmed),
                              trailingComma: .commaToken(
                                presence: declaration.parameters.last == parameter ? .missing : .present
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
                    trailingTrivia: .newline
                  )
                },
                rightParen: .rightParenToken()
              )
            )
          )
        )
      )
    )
  }

  static func capture(_ baseName: TokenSyntax.Predefined) -> CodeBlockItemSyntax {
    CodeBlockItemSyntax(
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

  /// Generates: `autoLogger.emit(event: event)`
  static func emit() -> CodeBlockItemSyntax {
    CodeBlockItemSyntax(
      FunctionCallExprSyntax(
        calledExpression: MemberAccessExprSyntax(
          base: DeclReferenceExprSyntax(
            baseName: .predefined(.autoLogger)
          ),
          period: .periodToken(),
          name: .predefined(.emit)
        ),
        leftParen: .leftParenToken(),
        arguments: LabeledExprListSyntax(
          arrayLiteral: LabeledExprSyntax(
            label: .predefined(.event),
            colon: .colonToken(),
            expression: DeclReferenceExprSyntax(baseName: .predefined(.event))
          )
        ),
        rightParen: .rightParenToken()
      )
    )
  }

  /// Generates: `autoLogger.emitStart(event: event)`
  ///
  /// The `emitStart` default implementation on `AutoLogger` checks
  /// `AutoLogSettingsStorage.emitStartEvents` at runtime before emitting.
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
          arrayLiteral: LabeledExprSyntax(
            label: .predefined(.event),
            colon: .colonToken(),
            expression: DeclReferenceExprSyntax(baseName: .predefined(.event))
          )
        ),
        rightParen: .rightParenToken()
      )
    )
  }

  /// Generates: `event.isMeasuredExplicitly = true`
  ///
  /// Injected when `@Log(measure: true)` is used, so the formatter shows timing
  /// even when `AutoLogSettingsStorage.measureTimingDefault` is `false`.
  static func captureExplicitMeasure() -> CodeBlockItemSyntax {
    CodeBlockItemSyntax(
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
    yieldCaptureIndex: inout Int
  ) -> [CodeBlockItemSyntax] {
    statements.flatMap { statement in
      rewriteStatementItem(statement, yieldCaptureIndex: &yieldCaptureIndex)
    }
  }

  static func rewriteStatementItem(
    _ item: CodeBlockItemSyntax,
    yieldCaptureIndex: inout Int
  ) -> [CodeBlockItemSyntax] {
    guard case let .stmt(statement) = item.item else {
      return [item]
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
        yieldCaptureIndex: &yieldCaptureIndex
      )
      return [CodeBlockItemSyntax(expressionStmt)]
    }

    if var forStmt = statement.as(ForStmtSyntax.self) {
      forStmt.body.statements = CodeBlockItemListSyntax(
        rewriteStatements(
          Array(forStmt.body.statements),
          yieldCaptureIndex: &yieldCaptureIndex
        )
      )
      return [CodeBlockItemSyntax(forStmt)]
    }

    if var whileStmt = statement.as(WhileStmtSyntax.self) {
      whileStmt.body.statements = CodeBlockItemListSyntax(
        rewriteStatements(
          Array(whileStmt.body.statements),
          yieldCaptureIndex: &yieldCaptureIndex
        )
      )
      return [CodeBlockItemSyntax(whileStmt)]
    }

    if var repeatStmt = statement.as(RepeatStmtSyntax.self) {
      repeatStmt.body.statements = CodeBlockItemListSyntax(
        rewriteStatements(
          Array(repeatStmt.body.statements),
          yieldCaptureIndex: &yieldCaptureIndex
        )
      )
      return [CodeBlockItemSyntax(repeatStmt)]
    }

    if var guardStmt = statement.as(GuardStmtSyntax.self) {
      guardStmt.body.statements = CodeBlockItemListSyntax(
        rewriteStatements(
          Array(guardStmt.body.statements),
          yieldCaptureIndex: &yieldCaptureIndex
        )
      )
      return [CodeBlockItemSyntax(guardStmt)]
    }

    if var doStmt = statement.as(DoStmtSyntax.self) {
      doStmt.body.statements = CodeBlockItemListSyntax(
        rewriteStatements(
          Array(doStmt.body.statements),
          yieldCaptureIndex: &yieldCaptureIndex
        )
      )

      var catchClauses = doStmt.catchClauses
      for index in catchClauses.indices {
        var clause = catchClauses[index]
        clause.body.statements = CodeBlockItemListSyntax(
          rewriteStatements(
            Array(clause.body.statements),
            yieldCaptureIndex: &yieldCaptureIndex
          )
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
    yieldCaptureIndex: inout Int
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
        yieldCaptureIndex: &yieldCaptureIndex
      )

      var arguments = functionCall.arguments
      for index in arguments.indices {
        var argument = arguments[index]
        argument.expression = rewriteExpression(
          argument.expression,
          yieldCaptureIndex: &yieldCaptureIndex
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
      ifExpr.body.statements = CodeBlockItemListSyntax(
        rewriteStatements(
          Array(ifExpr.body.statements),
          yieldCaptureIndex: &yieldCaptureIndex
        )
      )

      if let elseBody = ifExpr.elseBody {
        switch elseBody {
        case .codeBlock(var codeBlock):
          codeBlock.statements = CodeBlockItemListSyntax(
            rewriteStatements(
              Array(codeBlock.statements),
              yieldCaptureIndex: &yieldCaptureIndex
            )
          )
          ifExpr.elseBody = .codeBlock(codeBlock)

        case .ifExpr(let nestedIf):
          let rewrittenNested = rewriteExpression(
            ExprSyntax(nestedIf),
            yieldCaptureIndex: &yieldCaptureIndex
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
