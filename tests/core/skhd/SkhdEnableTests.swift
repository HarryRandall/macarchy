import Foundation
import Testing

@testable import Macarchy

/// A disabled binding holds no chord, so its keys can be taken before it is
/// enabled again.
struct SkhdEnableTests {
    @Test("enable refuses a chord another live binding took while it was disabled")
    func enableClash() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "shortcuts-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let config = root.appending(path: "skhdrc")
        let snapshots = SnapshotStore(root: root.appending(path: "snapshots"))
        let text = """
            # Focus left
            ctrl + alt - h : yabai -m window --focus west
            # Open notes
            cmd - k : open -a Notes
            # Resize
            resize < ctrl + alt - j : echo resize

            """
        try text.write(to: config, atomically: true, encoding: .utf8)
        let shortcuts = SkhdShortcuts(
            integrations: Integrations { _, _ in
                CommandResult(command: "fake", status: 1, stderr: "Restart refused")
            },
            config: config, snapshots: snapshots)
        _ = try await shortcuts.disable(id: 1, revision: shortcuts.read().revision)
        _ = try await shortcuts.rebind(
            id: 3, revision: shortcuts.read().revision,
            chord: .init(modifiers: ["ctrl", "alt"], key: "h"))
        let taken = try String(contentsOf: config, encoding: .utf8)
        let captured = snapshots.list().count

        await #expect {
            try await shortcuts.enable(id: 1, revision: shortcuts.read().revision)
        } throws: {
            $0.localizedDescription
                == "⌃⌥H is now used by \"Open notes\". Change the keys of one of them before"
                + " enabling this shortcut."
        }
        #expect(try String(contentsOf: config, encoding: .utf8) == taken)
        #expect(snapshots.list().count == captured)

        // The same chord in another mode is no clash.
        _ = try await shortcuts.rebind(
            id: 3, revision: shortcuts.read().revision,
            chord: .init(modifiers: ["ctrl", "alt"], key: "k"))
        _ = try await shortcuts.disable(id: 5, revision: shortcuts.read().revision)
        _ = try await shortcuts.rebind(
            id: 3, revision: shortcuts.read().revision,
            chord: .init(modifiers: ["ctrl", "alt"], key: "j"))
        _ = try await shortcuts.enable(id: 1, revision: shortcuts.read().revision)
        _ = try await shortcuts.enable(id: 5, revision: shortcuts.read().revision)
        #expect(try shortcuts.read().bindings.allSatisfy { !$0.isDisabled })
    }
}
