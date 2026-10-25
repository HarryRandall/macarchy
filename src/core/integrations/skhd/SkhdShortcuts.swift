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

    /// The chord in a spelling skhd parses back. The interface sends what it
    /// recorded, so a key arrives here as a name, a character or a keycode;
    /// punctuation is written as a keycode because skhd reads `-`, `:` and
    /// `;` as its own syntax, and Backspace is `backspace`, not `delete`.
    public func validated() throws -> ShortcutChord {
        let allowed = [
            "fn", "ctrl", "alt", "shift", "cmd", "hyper", "meh", "lctrl", "rctrl",
            "lalt", "ralt", "lshift", "rshift", "lcmd", "rcmd"
        ]
        let named = Set(SkhdKey.named.keys).union(SkhdBinding.keyGlyphs.keys)
        let key = SkhdKey.spelling(key)
        let simple =
            key.range(
                of: #"\A(?:[a-z0-9]|0x[0-7]?[0-9a-f])\z"#,
                options: [.regularExpression, .caseInsensitive])
            != nil
        guard modifiers.allSatisfy(allowed.contains), Set(modifiers).count == modifiers.count,
            simple || named.contains(key)
        else { throw ConfigurationError("Record a supported key combination.") }
        return ShortcutChord(modifiers: modifiers, key: key)
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

    /// The file skhd reads, through a link to the person's own copy.
    public var configURL: URL { (config ?? Paths.skhdrc).resolvingSymlinksInPath() }

    public func read() throws -> ShortcutsSnapshot {
        let url = configURL
        let text = try String(contentsOf: url, encoding: .utf8)
        return ShortcutsSnapshot(revision: revision(text, url), bindings: SkhdConfig.parse(text))
    }

    private func revision(_ text: String, _ url: URL) -> String {
        SHA256.hash(data: Data((url.path + "\n" + text).utf8)).map { String(format: "%02x", $0) }
            .joined()
    }

    /// Another binding holding `chord` in a mode the binding `id` works in.
    public func validate(_ chord: ShortcutChord, excluding id: Int) throws -> Int? {
        let chord = try chord.validated()
        let bindings = try read().bindings
        return SkhdConfig.conflict(
            in: bindings, modifiers: chord.modifiers, key: chord.key,
            excluding: bindings.first { $0.id == id })?.id
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
            guard !binding.isDisabled else {
                throw ConfigurationError("Enable this shortcut before changing its keys.")
            }
            guard
                SkhdConfig.conflict(
                    in: bindings, modifiers: chord.modifiers, key: chord.key, excluding: binding)
                    == nil
            else {
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
            guard !binding.isDisabled else {
                throw ConfigurationError("This shortcut is already disabled.")
            }
            return SkhdConfig.disable(text, binding: binding)
        }
    }

    /// Undoes `disable` exactly, through the same snapshot, write and restart.
    /// A disabled binding holds no chord, so another may have taken its keys
    /// since; enabling then would leave two live bindings on one chord.
    public func enable(id: Int, revision: String) async throws -> CommandResult {
        try await write(revision: revision, reason: "shortcut enabled") { text in
            let bindings = SkhdConfig.parse(text)
            guard let binding = bindings.first(where: { $0.id == id }) else {
                return nil
            }
            guard binding.isDisabled else {
                throw ConfigurationError("This shortcut is already enabled.")
            }
            if let clash = SkhdConfig.conflict(
                in: bindings, modifiers: binding.modifiers, key: binding.key, excluding: binding)
            {
                throw ConfigurationError(
                    "\(binding.keyCaps.joined()) is now used by \(Self.name(of: clash, in: bindings))."
                        + " Change the keys of one of them before enabling this shortcut.")
            }
            return SkhdConfig.enable(text, binding: binding)
        }
    }

    /// A binding as a person would know it: its own skhdrc heading, the mode
    /// it switches to, or else its command.
    static func name(of binding: SkhdBinding, in bindings: [SkhdBinding]) -> String {
        if let section = binding.section,
            bindings.filter({ $0.section == section }).count == 1
        {
            return "\"\(section)\""
        }
        if let mode = binding.activatesMode { return "the switch to \(mode) mode" }
        if !binding.command.isEmpty { return "\"\(binding.command)\"" }
        return "another shortcut"
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
