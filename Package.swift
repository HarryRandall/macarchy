// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Macarchy",
    platforms: [.macOS("26.0")],
    products: [
        .executable(name: "MacarchySettings", targets: ["App"]),
        .executable(name: "macarchy", targets: ["CLI"])
    ],
    targets: [
        .target(name: "Macarchy", path: "src/core"),
        .executableTarget(name: "App", dependencies: ["Macarchy"], path: "src/desktop", exclude: ["ui"]),
        .executableTarget(name: "CLI", dependencies: ["Macarchy"], path: "src/cli"),
        .testTarget(name: "MacarchyTests", dependencies: ["Macarchy"], path: "tests/core"),
        .testTarget(name: "AppTests", dependencies: ["App", "Macarchy"], path: "tests/desktop")
    ],
    swiftLanguageModes: [.v6]
)
