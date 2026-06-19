// swift-tools-version: 6.0
import CompilerPluginSupport
import PackageDescription

let package = Package(
  name: "Swift-AutoLog",
  platforms: [
    .macOS(.v15),
    .iOS(.v17),
    .watchOS(.v11),
  ],
  products: [
    .library(
      name: "AutoLog",
      targets: ["AutoLog"]
    ),
    .library(
      name: "AutoLogSwiftUI",
      targets: ["AutoLogSwiftUI"]
    ),
    .library(
      name: "AutoLogSwiftLog",
      targets: ["AutoLogSwiftLog"]
    ),
    .library(
      name: "AutoLogSettingsUI",
      targets: ["AutoLogSettingsUI"]
    ),
    .executable(
      name: "AutoLogSettings",
      targets: ["AutoLogSettings"]
    ),
  ],
  dependencies: [
    .package(
      url: "https://github.com/swiftlang/swift-syntax.git",
      from: "603.0.0-latest"
    ),
    .package(
      url: "https://github.com/pointfreeco/swift-macro-testing.git",
      from: "0.6.3"
    ),
    .package(
      url: "https://github.com/swiftlang/swift-docc-plugin",
      from: "1.4.4"
    ),
    .package(
      url: "https://github.com/apple/swift-log.git",
      from: "1.6.0"
    ),
  ],
  targets: [
    .macro(
      name: "AutoLogMacro",
      dependencies: [
        .product(
          name: "SwiftSyntaxMacros",
          package: "swift-syntax"
        ),
        .product(
          name: "SwiftCompilerPlugin",
          package: "swift-syntax"
        )
      ]
    ),
    .target(
      name: "AutoLog",
      dependencies: [
        "AutoLogMacro"
      ]
    ),
    .target(
      name: "AutoLogSwiftUI",
      dependencies: [
        "AutoLog"
      ]
    ),
    .target(
      name: "AutoLogSwiftLog",
      dependencies: [
        "AutoLog",
        .product(
          name: "Logging",
          package: "swift-log"
        ),
      ]
    ),
    .testTarget(
      name: "AutoLogMacroTests",
      dependencies: [
        "AutoLogMacro",
        .product(
          name: "SwiftSyntaxMacrosTestSupport",
          package: "swift-syntax"
        ),
        .product(
          name: "MacroTesting",
          package: "swift-macro-testing"
        ),
      ]
    ),
    .testTarget(
      name: "AutoLogTests",
      dependencies: [
        "AutoLog",
        "AutoLogSwiftUI",
        "AutoLogSwiftLog",
      ]
    ),
    .target(
      name: "AutoLogSettingsUI",
      dependencies: [
        "AutoLog"
      ]
    ),
    .executableTarget(
      name: "AutoLogSettings",
      dependencies: [
        "AutoLogSettingsUI"
      ],
      // macOS-only companion settings app
      swiftSettings: [
        .define("AUTOLOG_SETTINGS_APP")
      ]
    ),
  ]
)

for target in package.targets {
  target.swiftSettings = [
    .swiftLanguageMode(.v6)
  ]
}
