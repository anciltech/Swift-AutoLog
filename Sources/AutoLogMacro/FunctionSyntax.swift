import SwiftSyntax

@dynamicMemberLookup
public struct FunctionSyntax {
  let syntax: FunctionDeclSyntax
  let attributes: [Attribute]
  let signature: Signature

  /// Returns the original body of the called function as an array of `CodeBlockItemSyntax`.
  /// If the function body is missing, an empty array is returned.
  var body: [CodeBlockItemSyntax] {
    self.syntax.body?.statements.compactMap { $0 } ?? []
  }

  subscript<T>(dynamicMember keyPath: KeyPath<Signature, T>) -> T {
    get { signature[keyPath: keyPath] }
  }

  /// Returns a description of the original function's signature.
  var description: String {
    var syntax = self.syntax
    syntax.attributes = []
    syntax.body = nil
    return syntax.trimmedDescription
  }

  /// Creates an `InitializerClauseSyntax` that initializes a copy of the called function with an `_` prefix,
  /// appending `try` and/or `await`  as needed based on function's declaration.
  var initializer: InitializerClauseSyntax {
    let expression = FunctionCallExprSyntax(
      calledExpression: DeclReferenceExprSyntax(
        baseName: .identifier("_\(self.syntax.name.text)")
      ),
      leftParen: .leftParenToken(),
      arguments: self.signature.arguments,
      rightParen: .rightParenToken()
    )

    switch (self.signature.isThrowing, self.signature.isAsync) {
    case (true, true):
      let awaitExprSyntax = AwaitExprSyntax(expression)
      let tryExprSyntax = TryExprSyntax(awaitExprSyntax)
      return InitializerClauseSyntax(value: tryExprSyntax)

    case (true, false):
      let tryExprSyntax = TryExprSyntax(expression)
      return InitializerClauseSyntax(value: tryExprSyntax)

    case (false, true):
      let awaitExprSyntax = AwaitExprSyntax(expression)
      return InitializerClauseSyntax(value: awaitExprSyntax)

    case (false, false):
      return InitializerClauseSyntax(value: expression)
    }
  }

  /// Creates an initializer that calls the underscored function copy while
  /// publishing this event's logical depth to downstream logged calls.
  var scopedInitializer: InitializerClauseSyntax {
    let callExpression = "_\(self.syntax.name.text)(\(self.signature.arguments.trimmedDescription))"
    let innerPrefix: String
    let outerPrefix: String

    switch (self.signature.isThrowing, self.signature.isAsync) {
    case (true, true):
      innerPrefix = "try await "
      outerPrefix = "try await "
    case (true, false):
      innerPrefix = "try "
      outerPrefix = "try "
    case (false, true):
      innerPrefix = "await "
      outerPrefix = "await "
    case (false, false):
      innerPrefix = ""
      outerPrefix = ""
    }

    return InitializerClauseSyntax(
      value: ExprSyntax(
        stringLiteral: """
        \(outerPrefix)AutoLogSource.withCallSiteDepth(event.callSiteDepth ?? AutoLogSource.nextCallSiteDepth) {
          \(innerPrefix)\(callExpression)
        }
        """
      )
    )
  }

  /// Returns `true` if the function includes any generic parameters, otherwise returns `false`.
  var isGeneric: Bool { self.syntax.genericParameterClause != nil }

  /// Produces a `FunctionDeclSyntax` that is prefixed with `_`, has all attributes, modifiers, and generic declarations removed.
  /// Uses the signature provided by the `plain` property of `Signature`.
  var plain: FunctionDeclSyntax {
    var syntax = self.syntax
    syntax.attributes = []
    syntax.modifiers = []
    syntax.name = .identifier("_\(self.syntax.name.text)")
    syntax.signature = self.signature.plain
    syntax.genericParameterClause = nil
    syntax.genericWhereClause = nil
    return syntax
  }

  struct Signature {
    let syntax: FunctionSignatureSyntax
    let parameters: [Parameter]

    /// Returns `true` if the function signature does not include a return clause, otherwise returns `false`.
    var isVoid: Bool { self.syntax.returnClause == nil }

    /// Returns `true` if the function returns an optional or implicitly
    /// unwrapped optional value.
    var returnsOptionalLike: Bool {
      guard let returnType = self.syntax.returnClause?.type else { return false }
      return Self.isOptionalLike(returnType)
    }

    /// Returns `true` if the function is marked `async`, otherwise, returns `false`.
    var isAsync: Bool { self.syntax.effectSpecifiers?.asyncSpecifier != nil }

    /// Returns `true` if the function is marked `throwing`, otherwise, returns `false`.
    var isThrowing: Bool { self.syntax.effectSpecifiers?.throwsClause != nil }

    /// Produces a `LabeledExprListSyntax` containing all parameters required by the copy of the original function.
    /// Handles cases where a parameter is preceded by the `@autoclosure` attribute or the `inout` keyword.
    /// Otherwise, a parameter is returned without any wrapping.
    var arguments: LabeledExprListSyntax {
      LabeledExprListSyntax(
        self.parameters.map { parameter in
          let presence: SourcePresence =
            self.parameters.last == parameter
            ? .missing
            : .present
          return parameter.asLabeledExprSyntax(trailingComma: presence)
        }
      )
    }

    /// Returns a `FunctionSignatureSyntax` by mapping parameters via `plain` representation from `Parameter`.
    var plain: FunctionSignatureSyntax {
      var syntax = self.syntax
      syntax.parameterClause.parameters = FunctionParameterListSyntax(self.parameters.map(\.plain))
      return syntax
    }

    struct Parameter: Equatable {
      let syntax: FunctionParameterSyntax

      /// Returns `true` if parameter is marked as `inout`, otherwise returns `false`.
      var isInout: Bool {
        guard let attributedType = AttributedTypeSyntax(self.syntax.type)
        else { return false }

        return attributedType.specifiers.contains { specifierType in
          switch specifierType {
          case let .simpleTypeSpecifier(syntax) where syntax.specifier.tokenKind == .keyword(.inout):
            return true

          default:
            return false
          }
        }
      }

      /// Returns `true` when parameter is preceded with `@autoclosure` attribute, otherwise returns `false`.
      var isAutoclosure: Bool {
        guard let attributedType = AttributedTypeSyntax(self.syntax.type)
        else { return false }

        return attributedType.attributes.contains { attribute in
          guard case let .attribute(syntax) = attribute else { return false }
          guard let name = syntax.attributeName.as(IdentifierTypeSyntax.self) else { return false }
          return name.name.tokenKind == .predefined(.autoclosure)
        }
      }

      /// Returns `true` if parameter type is optional or implicitly unwrapped
      /// optional. Macro-generated metadata boxes those explicitly to avoid
      /// optional-to-`Any` warnings at expansion sites.
      var isOptionalLike: Bool {
        FunctionSyntax.Signature.isOptionalLike(self.syntax.type)
      }

      func asLabeledExprSyntax(trailingComma presence: SourcePresence) -> LabeledExprSyntax {
        switch (self.isInout, self.isAutoclosure) {
        case (true, false):
          return LabeledExprSyntax(
            label: self.name,
            colon: .colonToken(),
            expression: InOutExprSyntax(
              expression: DeclReferenceExprSyntax(baseName: self.name)
            ),
            trailingComma: .commaToken(presence: presence)
          )

        case (false, true):
          return LabeledExprSyntax(
            label: self.name,
            colon: .colonToken(),
            expression: FunctionCallExprSyntax(
              calledExpression: DeclReferenceExprSyntax(baseName: self.name),
              leftParen: .leftParenToken(),
              arguments: [],
              rightParen: .rightParenToken()
            ),
            trailingComma: .commaToken(presence: presence)
          )

        default:
          return LabeledExprSyntax(
            label: self.name,
            colon: .colonToken(),
            expression: DeclReferenceExprSyntax(baseName: self.name),
            trailingComma: .commaToken(presence: presence)
          )
        }
      }

      /// Returns the function's parameter name, disregarding any provided label.
      /// eg.  `name` for `func foo(bar baz: Biz)` signature will return `baz`.
      var name: TokenSyntax {
        guard let identifer = self.syntax.secondName
        else { return self.syntax.firstName }
        return identifer
      }

      /// Returns `FunctionParameterSyntax` stripped of any parameter label, default values and types.
      var plain: FunctionParameterSyntax {
        var syntax = self.syntax
        syntax.firstName = self.name
        syntax.secondName = nil
        syntax.defaultValue = nil
        syntax.type = self.syntax.type.trimmed
        return syntax
      }
    }

    init(syntax: FunctionSignatureSyntax) {
      self.syntax = syntax
      self.parameters = syntax.parameterClause.parameters.map(Parameter.init)
    }

    private static func isOptionalLike(_ type: TypeSyntax) -> Bool {
      let type = type.trimmed

      if type.is(OptionalTypeSyntax.self) || type.is(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
        return true
      }

      if let attributedType = type.as(AttributedTypeSyntax.self) {
        return isOptionalLike(attributedType.baseType)
      }

      return false
    }
  }

  struct Attribute {
    let syntax: AttributeSyntax
    let name: TokenSyntax

    var isLogMacroPresent: Bool {
      self.name == .identifier("OSLog")
    }
  }

  init(_ syntax: FunctionDeclSyntax) {
    self.syntax = syntax
    self.signature = Signature(syntax: syntax.signature)
    self.attributes = syntax.attributes.compactMap(\.asFunctionSyntaxAttribute)
  }

  init?(from syntax: some DeclSyntaxProtocol) {
    guard let syntax = syntax.as(FunctionDeclSyntax.self)
    else { return nil }
    self.init(syntax)
  }
}

@dynamicMemberLookup
public struct InitializerSyntax {
  let syntax: InitializerDeclSyntax
  let attributes: [FunctionSyntax.Attribute]
  let signature: FunctionSyntax.Signature

  /// Returns the original body of the called initializer as an array of `CodeBlockItemSyntax`.
  /// If the initializer body is missing, an empty array is returned.
  var body: [CodeBlockItemSyntax] {
    self.syntax.body?.statements.compactMap { $0 } ?? []
  }

  subscript<T>(dynamicMember keyPath: KeyPath<FunctionSyntax.Signature, T>) -> T {
    get { signature[keyPath: keyPath] }
  }

  /// Returns a description of the original initializer's signature.
  var description: String {
    var syntax = self.syntax
    syntax.attributes = []
    syntax.body = nil
    return syntax.trimmedDescription
  }

  init(_ syntax: InitializerDeclSyntax) {
    self.syntax = syntax
    self.signature = FunctionSyntax.Signature(syntax: syntax.signature)
    self.attributes = syntax.attributes.compactMap(\.asFunctionSyntaxAttribute)
  }

  init?(from syntax: some DeclSyntaxProtocol) {
    guard let syntax = syntax.as(InitializerDeclSyntax.self)
    else { return nil }
    self.init(syntax)
  }
}

extension AttributeListSyntax.Element {
  var asFunctionSyntaxAttribute: FunctionSyntax.Attribute? {
    guard
      case let .attribute(syntax) = self,
      let identifier = IdentifierTypeSyntax(syntax.attributeName)
    else { return nil }
    return FunctionSyntax.Attribute(
      syntax: syntax,
      name: identifier.name
    )
  }
}
