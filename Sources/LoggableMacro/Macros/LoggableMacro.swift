import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

protocol LoggableMacro: BodyMacro {
  static func initialize(for node: AttributeSyntax) -> ExprSyntax
}

extension LoggableMacro {
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
          baseName: .predefined(.LoggableSource)
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

      // Emit 🔵 start event (respects LoggableSettingsStorage.emitStartEvents at runtime).
      self.emitStart()

      // Capture timing start (compile-time opt-out via measure: false).
      if shouldMeasure {
        self.captureTimingStart()
      }

      switch function.isThrowing {
        case false where function.isVoid:
          function.body
          if shouldMeasure { self.captureTimingEnd() }
          self.emit()

        case true where function.isVoid:
          // Fixed: now emits on success too (paired with the start event).
          CodeBlockItemSyntax(function.plain)
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
          CodeBlockItemSyntax(function.plain)
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
          CodeBlockItemSyntax(function.plain)
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
              identifier: .predefined(.loggable)
            ),
            typeAnnotation: TypeAnnotationSyntax(
              type: SomeOrAnyTypeSyntax(
                someOrAnySpecifier: .keyword(.any),
                constraint: IdentifierTypeSyntax(
                  name: .predefined(.Loggable)
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
                  baseName: .predefined(.LoggableEvent)
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
                        baseName: .predefined(.LoggableSource)
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

  /// Generates: `loggable.emit(event: event)`
  static func emit() -> CodeBlockItemSyntax {
    CodeBlockItemSyntax(
      FunctionCallExprSyntax(
        calledExpression: MemberAccessExprSyntax(
          base: DeclReferenceExprSyntax(
            baseName: .predefined(.loggable)
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

  /// Generates: `loggable.emitStart(event: event)`
  ///
  /// The `emitStart` default implementation on `Loggable` checks
  /// `LoggableSettingsStorage.emitStartEvents` at runtime before emitting.
  static func emitStart() -> CodeBlockItemSyntax {
    CodeBlockItemSyntax(
      FunctionCallExprSyntax(
        calledExpression: MemberAccessExprSyntax(
          base: DeclReferenceExprSyntax(baseName: .predefined(.loggable)),
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
  /// even when `LoggableSettingsStorage.measureTimingDefault` is `false`.
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
}
