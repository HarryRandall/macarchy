// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Macarchy",
    platforms: [.macOS("26.0")],
    products: [
        // Installed binary keeps this name so the .app, Info.plist, and
        // `pkill -x MacarchySettings` stay stable.
        .executable(name: "MacarchySettings", targets: ["Settings"]),
        .executable(name: "macarchy", targets: ["CLI"])
    ],
    targets: [
        // Pure logic shared by the app and the CLI. Ported shell surfaces land
        // here so both entry points run exactly one implementation — the app and
        // the theme-cycling hotkey must never disagree about what a theme means.
        .target(
            name: "Kit",
            path: "Kit",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "Settings",
            dependencies: ["Kit"],
            path: "Settings",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "KitTests",
            dependencies: ["Kit"],
            path: "Tests/Kit",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "CLI",
            dependencies: ["Kit"],
            path: "CLI",
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
