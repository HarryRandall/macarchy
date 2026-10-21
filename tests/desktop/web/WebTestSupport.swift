import AppKit
import Foundation
import Testing

@testable import App
@testable import Macarchy

// Shared setup for the web view tests: the React pages, loaded from the built
// `dist` through the real scheme handler, against a temporary home and a fake
// desktop. Nothing here may reach the running desktop: windows are never
// shown, every executable is answered by the fake, and theme actions are
// recorded instead of run.
//
// The rest of the support is split by concern:
// - `WebTestSupport+Fakes.swift`: `FakeDesktop` and `ThemeRecorder`.
// - `WebTestSupport+Page.swift`: scripts, DOM helpers and polling.
// - `WebTestSupport+Keyboard.swift`: native key presses and off-screen hosting.
// - `WebTestSupport+Focus.swift`: where focus is and whether it shows.
// - `WebTestSupport+Snapshots.swift`: pictures of pages for review.

let repository = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent()
let interfaceDist = repository.appending(path: "src/desktop/ui/dist")
let interfaceBuilt = FileManager.default.fileExists(
    atPath: interfaceDist.appending(path: "settings.html").path)
let interfaceRequired = ProcessInfo.processInfo.environment["MACARCHY_REQUIRE_UI_TESTS"] == "1"

/// Points the scheme handler at `dist` and keeps the search path away from
/// Homebrew for the whole suite, then puts every variable back.
struct WebEnvironment: SuiteTrait, TestScoping {
    static let names = ["MACARCHY_HOME", "MACARCHY_SEARCH_PATH", "MACARCHY_UI_DIST"]

    func provideScope(
        for test: Test, testCase: Test.Case?, performing function: @Sendable () async throws -> Void
    ) async throws {
        let previous = Self.names.map { name in getenv(name).map { String(cString: $0) } }
        setenv("MACARCHY_UI_DIST", interfaceDist.path, 1)
        defer {
            for (name, value) in zip(Self.names, previous) {
                if let value { setenv(name, value, 1) } else { unsetenv(name) }
            }
        }
        try await function()
    }
}

/// The parent of every web view suite. Each `Harness` sets `MACARCHY_HOME`
/// and `MACARCHY_SEARCH_PATH` for the whole process, so these suites must
/// never run at the same time as each other. A new page suite joins by
/// nesting itself here, in its own file, which gives it `.serialized`, the
/// environment and the `dist` gating:
///
///     extension WebInterfaceTests {
///         @MainActor
///         @Suite("Borders page")
///         struct BordersPageTests {
///             @Test("...") func something() async throws {
///                 try await withHarness(tools: ["borders"]) { harness in ... }
///             }
///         }
///     }
///
/// A top-level suite that makes a `Harness` would run in parallel with these
/// and fight over the variables.
@MainActor
@Suite(
    "React interface in WKWebView", .serialized, WebEnvironment(),
    .enabled(
        if: interfaceBuilt || interfaceRequired,
        "src/desktop/ui/dist is not built; set MACARCHY_REQUIRE_UI_TESTS=1 to fail instead"))
struct WebInterfaceTests {}

// MARK: - Harness

/// One temporary home, with bundled themes, a settings file and fake tools on
/// the search path, and an app model wired to the fake desktop.
@MainActor
final class Harness {
    let home: URL
    let store: SettingsStore
    let desktop = FakeDesktop()
    let model: AppModel
    /// `~/.config/macarchy` inside the temporary home.
    var root: URL { home.appending(path: ".config/macarchy") }
    var themes: URL { root.appending(path: "themes") }
    /// The only directory on `MACARCHY_SEARCH_PATH`.
    var bin: URL { home.appending(path: "bin") }

    /// `themes` names the bundled themes to copy, or nil for all of them.
    /// `tools` are installed as executables, so they read as present; the
    /// fake answers instead, and they never run.
    init(
        settings: [String: String], currentTheme: String, themes chosen: [String]?,
        tools: [String]
    ) throws {
        try #require(
            interfaceBuilt,
            "src/desktop/ui/dist is missing. Build the interface with corepack pnpm run build.")
        _ = NSApplication.shared

        let fm = FileManager.default
        home = fm.temporaryDirectory.appending(path: "macarchy-web-test-\(UUID())")
        let bundled = repository.appending(path: "resources/themes")
        let themes = home.appending(path: ".config/macarchy/themes")
        if let chosen {
            try fm.createDirectory(at: themes, withIntermediateDirectories: true)
            for name in chosen {
                try fm.copyItem(
                    at: bundled.appending(path: name), to: themes.appending(path: name))
            }
        } else {
            try fm.createDirectory(
                at: themes.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.copyItem(at: bundled, to: themes)
        }

        try fm.createDirectory(at: home.appending(path: "bin"), withIntermediateDirectories: true)
        setenv("MACARCHY_HOME", home.path, 1)
        setenv("MACARCHY_SEARCH_PATH", home.appending(path: "bin").path, 1)

        store = SettingsStore(url: home.appending(path: ".config/macarchy/settings.json"))
        try store.update { document in
            document.currentTheme = currentTheme
            document.mergeFlat(settings)
        }
        let desktop = desktop
        model = AppModel(
            backend: Integrations { path, arguments in await desktop.run(path, arguments) },
            settingsStore: store)
        for tool in tools { try install(tool) }
        model.themes.reload()
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: home)
    }

    var settingsData: Data { (try? Data(contentsOf: store.url)) ?? Data() }

    /// Puts an executable named `tool` on the search path, so it reads as
    /// installed but not responding unless the fake answers for it.
    func install(_ tool: String) throws {
        let file = bin.appending(path: tool)
        try Data("#!/bin/sh\nexit 1\n".utf8).write(to: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
    }

    /// Writes `text` to `path`, relative to the home, making its folders.
    func write(_ text: String, to path: String) throws {
        let file = home.appending(path: path)
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: file)
    }

    /// A small real PNG, so thumbnails decode.
    func addBackground(theme: String, name: String, red: CGFloat) throws {
        let folder = themes.appending(path: "\(theme)/backgrounds")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let image = try #require(
            NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: 64, pixelsHigh: 36, bitsPerSample: 8,
                samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                bytesPerRow: 0, bitsPerPixel: 0))
        let colour = NSColor(deviceRed: red, green: 0.4, blue: 0.6, alpha: 1)
        for x in 0..<64 { for y in 0..<36 { image.setColor(colour, atX: x, y: y) } }
        try #require(image.representation(using: .png, properties: [:]))
            .write(to: folder.appending(path: name))
    }

    /// The settings window's page on `pane`, loading but never shown. The
    /// selection persists in the test process's defaults, so every page sets
    /// it rather than inheriting the previous test's.
    func settingsPage(pane: Pane = .layout) throws -> (SettingsWindow, WebSurface) {
        InterfacePreferences.selectedPane = pane
        let window = SettingsWindow()
        window.attach(model)
        return (window, try #require(window.preload()))
    }

    /// The switcher's page, with theme actions going to `recorder`.
    func switcherPage(recorder: ThemeRecorder) throws -> (ThemeSwitcher, WebSurface) {
        let switcher = ThemeSwitcher()
        switcher.actions = recorder.actions
        switcher.attach(model, registerShortcut: false)
        return (switcher, try #require(switcher.surface))
    }
}

/// Runs `body` with a fresh `Harness`, removing its home afterwards.
@MainActor
func withHarness(
    settings: [String: String] = [:], currentTheme: String = "lumon", themes: [String]? = nil,
    tools: [String] = ["yabai"], _ body: (Harness) async throws -> Void
) async throws {
    let harness = try Harness(
        settings: settings, currentTheme: currentTheme, themes: themes, tools: tools)
    defer { harness.cleanUp() }
    try await body(harness)
}
