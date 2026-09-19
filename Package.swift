// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Macarchy",
    platforms: [.macOS("26.0")],
    products: [
        // Installed binary keeps this name so the .app, Info.plist, and
        // `pkill -x MacarchySettings` stay stable.
        .executable(name: "MacarchySettings", targets: ["Settings"]),
        .executable(name: "macarchy", targets: ["macarchy"])
    ],
    targets: [
        // One folder per program the desktop runs. Ported shell surfaces land
        // beside the tool they drive, so the app and the theme-cycling hotkey
        // run exactly one implementation and cannot disagree about a theme.
        .target(
            name: "Desktop",
            path: "Desktop",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "Settings",
            dependencies: ["Desktop"],
            path: "Settings",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "DesktopTests",
            dependencies: ["Desktop"],
            path: "Tests/Desktop",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "macarchy",
            dependencies: ["Desktop"],
            path: "macarchy",
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
