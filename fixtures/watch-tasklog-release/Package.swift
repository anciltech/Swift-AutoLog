// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "WatchTaskLogReleaseFixture",
  platforms: [
    .watchOS(.v11),
  ],
  products: [
    .executable(
      name: "WatchTaskLogReleaseFixture",
      targets: ["WatchTaskLogReleaseFixture"]
    ),
  ],
  dependencies: [
    .package(path: "../.."),
  ],
  targets: [
    .executableTarget(
      name: "WatchTaskLogReleaseFixture",
      dependencies: [
        .product(name: "AutoLogSwiftUI", package: "Swift-AutoLog"),
      ]
    ),
  ]
)
