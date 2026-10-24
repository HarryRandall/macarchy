import CryptoKit
import Foundation

public struct ShortcutsSnapshot: Sendable {
    public let revision: String
    public let bindings: [SkhdBinding]
}

public struct ShortcutChord: Codable, Sendable, Equatable {
    public var modifiers: [String]
    public var key: String

    public init(modifiers: [String], key: String) {
        self.modifiers = modifiers
        self.key = key
    }

    public var keySpec: String { SkhdConfig.keySpec(modifiers: modifiers, key: key) }
    public var caps: [String] {
        SkhdConfig.parse("\(keySpec) : placeholder").first?.keyCaps ?? []
    }

    public func validated() throws -> ShortcutChord {
        let allowed = [
            "fn", "ctrl", "alt", "shift", "cmd", "hyper", "lctrl", "rctrl",
            "lalt", "ralt", "lshift", "rshift", "lcmd", "rcmd"
        ]
        let named = Set(SkhdBinding.keyGlyphs.keys).union((1...20).map { "f\($0)" })
        let key = key.lowercased()
        let simple =
            key.range(of: #"\A(?:[a-z0-9]|0x[0-7]?[0-9a-f])\z"#, options: .regularExpression) != nil
        guard modifiers.allSatisfy(allowed.contains), Set(modifiers).count == modifiers.count,
            simple || named.contains(key)
        else { throw ConfigurationError("Record a supported key combination.") }
        return ShortcutChord(modifiers: modifiers, key: key)
    }

    /// Physical keycodes and their named equivalents must conflict too.
    func overlaps(_ binding: SkhdBinding) -> Bool {
        func keys(_ key: String) -> String {
            let names: [Int: String] = [
                0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x",
                8: "c", 9: "v", 11: "b", 12: "q", 13: "w", 14: "e", 15: "r",
                16: "y", 17: "t", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
                23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
                30: "]", 31: "o", 32: "u", 33: "[", 34: "i", 35: "p", 36: "return",
                37: "l", 38: "j", 39: "'", 40: "k", 41: ";", 42: "\\", 43: ",",
                44: "/", 45: "n", 46: "m", 47: ".", 48: "tab", 49: "space", 50: "`",
                51: "delete", 53: "escape", 64: "f17", 79: "f18", 80: "f19", 90: "f20",
                96: "f5", 97: "f6", 98: "f7", 99: "f3", 100: "f8", 101: "f9",
                103: "f11", 105: "f13", 106: "f16", 107: "f14", 109: "f10", 111: "f12",
                113: "f15", 115: "home", 116: "pageup", 118: "f4", 119: "end",
                120: "f2", 121: "pagedown", 122: "f1", 123: "left", 124: "right",
                125: "down", 126: "up"
            ]
            let key = key.lowercased()
            guard key.hasPrefix("0x"), let code = Int(key.dropFirst(2), radix: 16) else {
                return key
            }
            return names[code] ?? "0x" + String(code, radix: 16)
        }
        func expanded(_ values: [String]) -> Set<String> {
            Set(
                values.flatMap { value -> [String] in
                    if value == "hyper" { return ["ctrl", "alt", "shift", "cmd"] }
                    if value == "opt" { return ["alt"] }
                    if value.hasPrefix("l") || value.hasPrefix("r") {
                        return [String(value.dropFirst())]
                    }
                    return [value]
                })
        }
        return keys(key) == keys(binding.key) && expanded(modifiers) == expanded(binding.modifiers)
    }
}

/// skhdrc stays the person's file. Reads never create it or seed defaults.
public struct SkhdShortcuts: Sendable {
    private let integrations: Integrations
    private let config: URL?
    private let snapshots: SnapshotStore
    private let defaultsURL: URL?

    public init(
        integrations: Integrations = Integrations(), config: URL? = nil,
        snapshots: SnapshotStore = SnapshotStore(), defaultsURL: URL? = nil
    ) {
        self.integrations = integrations
        self.config = config
        self.snapshots = snapshots
        self.defaultsURL = defaultsURL
    }

    public var configURL: URL { (config ?? Setup.skhdrc).resolvingSymlinksInPath() }

    public func read() throws -> ShortcutsSnapshot {
        let url = configURL
        let text = try String(contentsOf: url, encoding: .utf8)
        return ShortcutsSnapshot(revision: revision(text, url), bindings: SkhdConfig.parse(text))
    }

    private func revision(_ text: String, _ url: URL) -> String {
        SHA256.hash(data: Data((url.path + "\n" + text).utf8)).map { String(format: "%02x", $0) }
            .joined()
    }

    public func validate(_ chord: ShortcutChord, excluding id: Int) throws -> Int? {
        let chord = try chord.validated()
        return try read().bindings.first { $0.id != id && chord.overlaps($0) }?.id
    }

    public func rebind(
        id: Int, revision: String, chord: ShortcutChord
    ) async throws -> CommandResult {
        let chord = try chord.validated()
        return try await write(revision: revision, reason: "shortcut rebind") { text in
            let bindings = SkhdConfig.parse(text)
            guard let binding = bindings.first(where: { $0.id == id }) else {
                throw ConfigurationError(
                    "This shortcut no longer exists. Refresh shortcuts and try again.")
            }
            guard !bindings.contains(where: { $0.id != id && chord.overlaps($0) }) else {
                throw ConfigurationError("Another shortcut already uses this combination.")
            }
            return SkhdConfig.rebind(
                text, binding: binding, modifiers: chord.modifiers, key: chord.key)
        }
    }

    public func disable(id: Int, revision: String) async throws -> CommandResult {
        try await write(revision: revision, reason: "shortcut disabled") { text in
            guard let binding = SkhdConfig.parse(text).first(where: { $0.id == id }) else {
                return nil
            }
            return SkhdConfig.disable(text, binding: binding)
        }
    }

    /// Only an explicitly confirmed reset may replace the person's commands.
    public func reset(revision: String) async throws -> CommandResult {
        guard let source = defaultsURL ?? Paths.resources?.appending(path: "skhd/skhdrc") else {
            throw ConfigurationError("Default shortcuts are missing. Reinstall Macarchy.")
        }
        let defaults = try String(contentsOf: source, encoding: .utf8)
        return try await write(revision: revision, reason: "reset shortcuts") { _ in defaults }
    }

    private func write(
        revision expected: String, reason: String,
        edit: @Sendable @escaping (String) throws -> String?
    ) async throws -> CommandResult {
        try await OperationLock.run(root: snapshots.root.deletingLastPathComponent()) {
            let url = configURL
            try FileLock.withLock(url) {
                let text = try String(contentsOf: url, encoding: .utf8)
                guard revision(text, url) == expected, let updated = try edit(text) else {
                    throw ConfigurationError(
                        "skhdrc changed since it was read. Refresh shortcuts and try again.")
                }
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                try snapshots.capture([url], reason: reason)
                // An external editor does not share our lock. Recheck after taking the snapshot.
                guard try String(contentsOf: url, encoding: .utf8) == text else {
                    throw ConfigurationError(
                        "skhdrc changed while saving. Refresh shortcuts and try again.")
                }
                try updated.write(to: url, atomically: true, encoding: .utf8)
                if let permissions = attributes[.posixPermissions] {
                    do {
                        try FileManager.default.setAttributes(
                            [.posixPermissions: permissions], ofItemAtPath: url.path)
                    } catch {
                        throw ConfigurationError(
                            "Shortcuts were saved, but file permissions could not be restored: \(error.localizedDescription)"
                        )
                    }
                }
            }
            guard Paths.isInstalled("skhd") else {
                return CommandResult(
                    command: reason, status: 0,
                    stdout: "Saved. skhd is not installed; reload was skipped.")
            }
            let reload = await integrations.restart(.skhd)
            guard reload.ok else {
                return CommandResult(
                    command: reason, status: 1,
                    stderr: "Shortcuts were saved, but skhd could not restart. \(reload.stderr)")
            }
            return reload
        }
    }
}
