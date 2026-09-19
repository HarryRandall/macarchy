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
        .target(name: "Macarchy", path: "src/macarchy"),
        .executableTarget(name: "App", dependencies: ["Macarchy"], path: "src/app", exclude: ["resources"]),
        .executableTarget(name: "CLI", dependencies: ["Macarchy"], path: "src/cli"),
        .testTarget(name: "MacarchyTests", dependencies: ["Macarchy"], path: "tests/macarchy"),
        .testTarget(name: "AppTests", dependencies: ["App", "Macarchy"], path: "tests/app")
    ],
    swiftLanguageModes: [.v6]
)
