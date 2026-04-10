import Foundation
import SwiftSyntax

extension ExprSyntaxProtocol {
  var isOmitParameters: Bool {
    switch ExprSyntax(fromProtocol: self).as(ExprSyntaxEnum.self) {
      case let .memberAccessExpr(memberAccessExprSyntax):
        return memberAccessExprSyntax.declName.baseName.text == "parameters"
        
      case let .stringLiteralExpr(stringLiteralExprSynta):
        return stringLiteralExprSynta.isEqual(to: "__parameters")
        
      default:
        return false
    }
  }
  
  var isOmitResult: Bool {
    switch ExprSyntax(fromProtocol: self).as(ExprSyntaxEnum.self) {
      case let .memberAccessExpr(memberAccessExprSyntax):
        return memberAccessExprSyntax.declName.baseName.text == "result"
        
      case let .stringLiteralExpr(stringLiteralExprSyntax):
        return stringLiteralExprSyntax.isEqual(to: "__result")
        
      default:
        return false
    }
  }

  var isOmitError: Bool {
    switch ExprSyntax(fromProtocol: self).as(ExprSyntaxEnum.self) {
      case let .memberAccessExpr(memberAccessExprSyntax):
        return memberAccessExprSyntax.declName.baseName.text == "error"

      case let .stringLiteralExpr(stringLiteralExprSyntax):
        return stringLiteralExprSyntax.isEqual(to: "__error")

      default:
        return false
    }
  }
  
  func isOmitParameter(_ label: TokenSyntax) -> Bool {
    switch ExprSyntax(fromProtocol: self).as(ExprSyntaxEnum.self) {
      case let .memberAccessExpr(memberAccessExprSyntax):
        return memberAccessExprSyntax.declName.baseName.tokenKind == label.tokenKind
        
      case let .stringLiteralExpr(stringLiteralExprSynta):
        return stringLiteralExprSynta.isEqual(to: label.text)
        
      default:
        return false
    }
  }
}

extension StringLiteralExprSyntax {
  fileprivate func isEqual(to text: String) -> Bool {
    switch self.segments.first {
      case let .stringSegment(stringSegmentSyntax):
        return stringSegmentSyntax.content.trimmedDescription == text
        
        
      default:
        return false
    }
  }
}

extension AttributeListSyntax {
  struct OmitRuleTrait {
    let scope: ExprSyntax
    let containing: ExprSyntax?
    let upToCount: ExprSyntax?
  }

  /// Extracts tag expressions in lexical source order across `@Tag(...)` and
  /// variadic `tag:` arguments attached to `@Log(...)` / `@OSLog(...)`.
  func extractTagTraitsInSourceOrder() -> [ExprSyntax] {
    attributesFromAllAttachedAnnotations
      .flatMap { annotation, attributes -> [(Int, ExprSyntax)] in
        switch annotation {
        case .predefined(.Tag):
          return attributes.map { argument in
            (
              argument.expression.positionAfterSkippingLeadingTrivia.utf8Offset,
              ExprSyntax(argument.expression)
            )
          }

        case .predefined(.Log), .predefined(.OSLog):
          return attributes
            .extractVariadicArguments(for: .tag)
            .map { argument in
              (
                argument.expression.positionAfterSkippingLeadingTrivia.utf8Offset,
                ExprSyntax(argument.expression)
              )
            }

        default:
          return []
        }
      }
      .sorted { lhs, rhs in lhs.0 < rhs.0 }
      .map(\.1)
  }

  /// Extracts all arguments passed as parameters to given annotation as well
  /// all arguments found in trait annotations.
  ///
  var attributesFromAllAttachedAnnotations: [(TokenKind, LabeledExprListSyntax)] {
    self.compactMap { element -> (TokenKind, LabeledExprListSyntax)? in
      guard
        case let .attribute(attributeSyntax) = element,
        let tokenKind = IdentifierTypeSyntax(attributeSyntax.attributeName)?.name.tokenKind
      else { return nil }

      let arguments = LabeledExprListSyntax(attributeSyntax.arguments) ?? []
      return (tokenKind, arguments)
    }
  }
  
  func extractTraits(for label: TokenKind.Predefined) -> [any ExprSyntaxProtocol] {
    self.attributesFromAllAttachedAnnotations
      .flatMap { annotation, attributes -> [any ExprSyntaxProtocol] in
        switch annotation {
          case .predefined(.Tag) where label == .tag:
            return attributes.map(\.expression)
            
          case .predefined(.Omit) where label == .omit:
            let hasConditionalArguments = attributes.contains { element in
              guard let tokenKind = element.label?.tokenKind else { return false }
              return tokenKind == .predefined(.containing) || tokenKind == .predefined(.upToCount)
            }

            guard hasConditionalArguments else {
              return attributes.map(\.expression)
            }

            return attributes
              .filter { $0.label == nil }
              .map(\.expression)
              .filter { !$0.isOmitResult && !$0.isOmitError }
            
          case .predefined(.Level) where label == .level:
            return attributes.map(\.expression)

          case .predefined(.Deduplicate) where label == .deduplicate:
            return attributes.map(\.expression)

          case .predefined(.When) where label == .when:
            return attributes.map(\.expression)
            
          case .predefined(.Log), .predefined(.OSLog):
            return attributes
              .extractVariadicArguments(for: label)
              .map(\.expression)
            
          default:
            return []
        }
      }
  }

  func extractOmitRuleTraits() -> [OmitRuleTrait] {
    attributesFromAllAttachedAnnotations.compactMap { annotation, attributes in
      guard annotation == .predefined(.Omit) else { return nil }

      let hasConditionalArguments = attributes.contains { element in
        guard let tokenKind = element.label?.tokenKind else { return false }
        return tokenKind == .predefined(.containing) || tokenKind == .predefined(.upToCount)
      }

      guard hasConditionalArguments else { return nil }
      guard let scope = attributes.first(where: { $0.label == nil })?.expression else { return nil }

      let containing = attributes.first(where: {
        $0.label?.tokenKind == .predefined(.containing)
      })?.expression

      let upToCount = attributes.first(where: {
        $0.label?.tokenKind == .predefined(.upToCount)
      })?.expression

      return OmitRuleTrait(
        scope: ExprSyntax(scope),
        containing: containing.map { ExprSyntax($0) },
        upToCount: upToCount.map { ExprSyntax($0) }
      )
    }
  }

  var hasBareOmitMarker: Bool {
    attributesFromAllAttachedAnnotations.contains { annotation, attributes in
      annotation == .predefined(.Omit) && attributes.isEmpty
    }
  }
}

extension LabeledExprListSyntax {
  /// Extract arguments passed to variadic parameter.
  ///
  /// - parameters:
  ///   - label: Variadic parameter label that preceeds arguments.
  ///
  /// - returns:
  ///   - `LabeledExprListSyntax` that contains only arguments from specified
  ///      parameter label.
  ///
  func extractVariadicArguments(for label: TokenKind.Predefined) -> LabeledExprListSyntax {
    /// Find the start index of element with label that matches one passed as argument
    guard let startIndex = self.firstIndex(
      where: { $0.label?.tokenKind == label.identifier }
    ) else {
      return []
    }

    /// Create a range thats starts after `startIndex`, otherwise `startIndex`
    /// would be classified as `endIndex` too
    let range = self.index(after: startIndex)...
    
    /// Check for any other vardict parameter lables that might come after specifed one
    /// If non found, end of arguments is reached
    let endIndex = self[range].firstIndex { $0.label != nil } ?? self.endIndex

    /// Return the slice from `startIndex` up to (but not including) `endIndex`
    return LabeledExprListSyntax(self[startIndex..<endIndex])
  }
}
