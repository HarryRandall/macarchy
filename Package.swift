// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacarchySettings",
    platforms: [.macOS("26.0")],
    products: [
        .executable(name: "MacarchySettings", targets: ["MacarchySettings"]),
        .executable(name: "macarchy", targets: ["MacarchyCLI"])
    ],
    targets: [
        // Pure logic shared by the app and the CLI. Ported shell surfaces land
        // here so both entry points run exactly one implementation — the app and
        // the theme-cycling hotkey must never disagree about what a theme means.
        .target(
            name: "MacarchyKit",
            path: "Sources/MacarchyKit",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "MacarchySettings",
            dependencies: ["MacarchyKit"],
            path: "Sources/MacarchySettings",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "MacarchyCLI",
            dependencies: ["MacarchyKit"],
            path: "Sources/MacarchyCLI",
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
