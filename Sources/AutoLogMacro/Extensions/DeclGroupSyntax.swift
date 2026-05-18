import SwiftSyntax

extension DeclGroupSyntax {
  var isGeneric: Bool {
    return switch DeclSyntax(self).as(DeclSyntaxEnum.self) {
    case let .actorDecl(actorDeclSyntax):
      actorDeclSyntax.genericParameterClause != nil

    case let .classDecl(classDeclSyntax):
      classDeclSyntax.genericParameterClause != nil

    case let .structDecl(structDeclSyntax):
      structDeclSyntax.genericParameterClause != nil

    case let .enumDecl(enumDeclSyntax):
      enumDeclSyntax.genericParameterClause != nil

    case let .extensionDecl(extensionDeclSyntax):
      extensionDeclSyntax.genericWhereClause != nil

    default:
      false
    }
  }

  var inheritedTypeNames: Set<String> {
    let inheritedTypes: InheritedTypeListSyntax? = switch DeclSyntax(self).as(DeclSyntaxEnum.self) {
    case let .actorDecl(actorDeclSyntax):
      actorDeclSyntax.inheritanceClause?.inheritedTypes

    case let .classDecl(classDeclSyntax):
      classDeclSyntax.inheritanceClause?.inheritedTypes

    case let .structDecl(structDeclSyntax):
      structDeclSyntax.inheritanceClause?.inheritedTypes

    case let .enumDecl(enumDeclSyntax):
      enumDeclSyntax.inheritanceClause?.inheritedTypes

    case let .extensionDecl(extensionDeclSyntax):
      extensionDeclSyntax.inheritanceClause?.inheritedTypes

    default:
      nil
    }

    guard let inheritedTypes else { return [] }
    return Set(
      inheritedTypes.map { inheritedType in
        inheritedType.type.trimmedDescription
      }
    )
  }

  func inherits(anyOf names: Set<String>) -> Bool {
    !inheritedTypeNames.isDisjoint(with: names)
  }
}
