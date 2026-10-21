import Foundation
import Testing

@testable import Macarchy

private actor BorderDesktop {
    var calls: [(String, [String])] = []
    var running = true
    var rejected = false

    func stop() { running = false }
    func reject() { rejected = true }
    func run(_ path: String, _ arguments: [String]) -> CommandResult {
        let tool = URL(fileURLWithPath: path).lastPathComponent
        calls.append((tool, arguments))
        if tool == "launchctl" {
            return CommandResult(
                command: tool, status: running ? 0 : 1,
                stdout: running ? "state = running\npid = 42" : "")
        }
        if tool == "defaults", arguments.first == "read" {
            return CommandResult(command: tool, status: 1, stderr: "does not exist")
        }
        return CommandResult(
            command: tool, status: rejected && tool == "borders" ? 1 : 0,
            stderr: rejected ? "Rejected" : "")
    }
    var writes: [[String]] { calls.filter { $0.0 == "borders" || $0.1.first == "write" }.map(\.1) }
}

struct BorderSettingsTests {
    private struct Fixture {
        let root: URL
        let store: SettingsStore
        let themes: URL
    }

    private func fixture() throws -> Fixture {
        let root = FileManager.default.temporaryDirectory.appending(path: "border-test-\(UUID())")
        let themes = root.appending(path: "themes")
        let directory = themes.appending(path: "example")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var theme = Theme(name: "example")
        theme.colors.borderActive = "0xff123456"
        try theme.write(to: directory)
        let store = SettingsStore(url: root.appending(path: "settings.json"))
        try store.update {
            $0.currentTheme = "example"
            $0.mergeFlat(["BORDER_WIDTH": "9", "BORDERS_BLACKLIST": "Messages,FaceTime"])
        }
        return Fixture(root: root, store: store, themes: themes)
    }

    private func operation(
        _ desktop: BorderDesktop, _ store: SettingsStore, _ themes: URL
    ) -> BorderSettings {
        BorderSettings(
            integrations: Integrations { await desktop.run($0, $1) },
            store: store, themes: themes, resources: themes.deletingLastPathComponent())
    }

    @Test("read combines saved values, observed corners and theme colours without writes")
    func readOnly() async throws {
        let fixture = try fixture()
        let root = fixture.root
        let store = fixture.store
        let themes = fixture.themes
        defer { try? FileManager.default.removeItem(at: root) }
        let desktop = BorderDesktop()
        let before = try Data(contentsOf: store.url)
        let state = try await operation(desktop, store, themes).read()
        #expect(state.appearance.width == 9)
        #expect(state.appearance.excludedApps == ["Messages", "FaceTime"])
        #expect(state.appearance.radius == nil)
        #expect(state.appearance.activeColour == "0xff123456")
        #expect(state.defaults?.activeColour == "0xff123456")
        #expect(state.unavailableReason == nil)
        #expect(await desktop.writes.isEmpty)
        #expect(try Data(contentsOf: store.url) == before)
    }

    @Test("stopped optional borders retains saved preferences and refuses writes")
    func stopped() async throws {
        let fixture = try fixture()
        let root = fixture.root
        let store = fixture.store
        let themes = fixture.themes
        defer { try? FileManager.default.removeItem(at: root) }
        let desktop = BorderDesktop()
        await desktop.stop()
        let operation = operation(desktop, store, themes)
        let state = try await operation.read()
        #expect(state.appearance.width == 9)
        #expect(state.unavailableReason != nil)
        let before = try Data(contentsOf: store.url)
        await #expect(throws: ConfigurationError.self) {
            try await operation.apply(state.appearance, theme: "example")
        }
        #expect(await desktop.writes.isEmpty)
        #expect(try Data(contentsOf: store.url) == before)
    }

    @Test("complete appearance applies before saving dimensions, exclusions and theme colours")
    func apply() async throws {
        let fixture = try fixture()
        let root = fixture.root
        let store = fixture.store
        let themes = fixture.themes
        defer { try? FileManager.default.removeItem(at: root) }
        let desktop = BorderDesktop()
        var appearance = BorderAppearance()
        appearance.width = 11
        appearance.radius = 0.3
        appearance.excludedApps = []
        appearance.activeColour = "0x80112233"
        appearance.inactiveColour = "0xff445566"
        try await operation(desktop, store, themes).apply(appearance, theme: "example")
        #expect(try store.read().flatValues["BORDER_WIDTH"] == "11")
        #expect(try store.read().flatValues["BORDERS_BLACKLIST"]?.isEmpty == true)
        #expect(try store.read().flatValues["BORDER_STYLE"] == "square")
        #expect(
            try Theme.read(from: themes.appending(path: "example")).colors.borderActive
                == "0x80112233")
        let writes = await desktop.writes
        #expect(writes.first == ["write", "-g", "NSConvolutionOverride1", "-float", "0.3"])
        #expect(writes.last?.contains("width=11.0") == true)
        #expect(writes.last?.contains("active_color=0x80112233") == true)
    }

    @Test("rejected application keeps both settings and theme unchanged")
    func rejected() async throws {
        let fixture = try fixture()
        let root = fixture.root
        let store = fixture.store
        let themes = fixture.themes
        defer { try? FileManager.default.removeItem(at: root) }
        let desktop = BorderDesktop()
        await desktop.reject()
        let before = try Data(contentsOf: store.url)
        let themeBefore = try Theme.read(from: themes.appending(path: "example"))
        var appearance = BorderAppearance()
        appearance.activeColour = "0xffabcdef"
        await #expect(throws: ConfigurationError.self) {
            try await operation(desktop, store, themes).apply(appearance, theme: "example")
        }
        #expect(try Data(contentsOf: store.url) == before)
        #expect(try Theme.read(from: themes.appending(path: "example")) == themeBefore)
    }

    @Test("validation and stale themes fail before desktop changes")
    func validation() async throws {
        let fixture = try fixture()
        let root = fixture.root
        let store = fixture.store
        let themes = fixture.themes
        defer { try? FileManager.default.removeItem(at: root) }
        let desktop = BorderDesktop()
        let operation = operation(desktop, store, themes)
        var appearance = BorderAppearance()
        appearance.width = 17
        await #expect(throws: ConfigurationError.self) {
            try await operation.apply(appearance, theme: "example")
        }
        appearance.width = 6
        appearance.excludedApps = ["Bad,Name"]
        await #expect(throws: ConfigurationError.self) {
            try await operation.apply(appearance, theme: "example")
        }
        await #expect(throws: ConfigurationError.self) {
            try await operation.apply(BorderAppearance(), theme: "other")
        }
        #expect(await desktop.writes.isEmpty)
    }

    @Test("failed persistence reports failure after application and retains saved preferences")
    func persistenceFailure() async throws {
        let fixture = try fixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let desktop = BorderDesktop()
        let operation = operation(desktop, fixture.store, fixture.themes)
        var appearance = try await operation.read().appearance
        appearance.width = 10
        let before = try Data(contentsOf: fixture.store.url)
        try Data().write(to: fixture.root.appending(path: "snapshots"))
        await #expect(throws: (any Error).self) {
            try await operation.apply(appearance, theme: "example")
        }
        #expect(await !desktop.writes.isEmpty)
        #expect(try Data(contentsOf: fixture.store.url) == before)
    }

    @Test("invalid saved data fails instead of showing defaults")
    func invalidSettings() async throws {
        let fixture = try fixture()
        let root = fixture.root
        let store = fixture.store
        let themes = fixture.themes
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("invalid".utf8).write(to: store.url)
        await #expect(throws: (any Error).self) {
            _ = try await operation(BorderDesktop(), store, themes).read()
        }
    }
}
