// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "BailongMac", platforms: [.macOS(.v14)],
    products: [.library(name: "BailongCore", targets: ["BailongCore"]), .executable(name: "BailongMac", targets: ["BailongMac"])],
    targets: [.target(name: "BailongCore"), .executableTarget(name: "BailongMac", dependencies: ["BailongCore"]), .executableTarget(name: "CoreChecks", dependencies: ["BailongCore"], path: "Tests/BailongCoreTests")],
    swiftLanguageModes: [.v5]
)
