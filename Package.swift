// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "PortBar",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "PortBar", targets: ["PortBar"])
  ],
  targets: [
    .target(name: "PortBarCore"),
    .executableTarget(
      name: "PortBar",
      dependencies: ["PortBarCore"]
    ),
    .testTarget(
      name: "PortBarCoreTests",
      dependencies: ["PortBarCore"]
    )
  ]
)
