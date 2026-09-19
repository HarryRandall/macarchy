// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacarchySettings",
    platforms: [.macOS("26.0")],
    targets: [
        .executableTarget(
            name: "MacarchySettings",
            path: "Sources/MacarchySettings",
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
