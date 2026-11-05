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
        // Instant Space switching, trimmed from InstantSpaceSwitcher (MIT).
        .target(
            name: "SpaceGesture", path: "src/space-gesture", exclude: ["README.md"],
            linkerSettings: [.linkedFramework("ApplicationServices")]),
        .target(name: "Macarchy", dependencies: ["SpaceGesture"], path: "src/core"),
        .executableTarget(name: "App", dependencies: ["Macarchy"], path: "src/desktop", exclude: ["ui"]),
        .executableTarget(name: "CLI", dependencies: ["Macarchy"], path: "src/cli"),
        .testTarget(
            name: "MacarchyTests", dependencies: ["Macarchy", "SpaceGesture"], path: "tests/core"),
        .testTarget(name: "AppTests", dependencies: ["App", "Macarchy"], path: "tests/desktop")
    ],
    swiftLanguageModes: [.v6]
)
