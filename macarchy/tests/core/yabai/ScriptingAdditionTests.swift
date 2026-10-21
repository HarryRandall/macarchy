import Foundation
import Testing

@testable import Macarchy

/// The hashes here are the real ones from the morning this check was written:
/// the sudoers rule still pinned the yabai binary from May, brew had replaced
/// it, and switching desktops had been silently dead since.
@Suite("ScriptingAddition")
struct ScriptingAdditionTests {
    private static let stale = "372ad557a7c54a6199a78dcbcefe5b60fd0224e5c1f5139cfaed00dfdaa44501"

    private func rule(_ digest: String, binary: String = "/opt/homebrew/bin/yabai") -> String {
        "alex ALL=(root) NOPASSWD: sha256:\(digest) \(binary) --load-sa\n"
    }

    @Test("reads the pinned hash out of a real rule")
    func pinned() {
        #expect(
            ScriptingAddition.pinnedDigest(
                in: rule(Self.stale), binary: "/opt/homebrew/bin/yabai") == Self.stale)
    }

    /// The file may hold rules for other commands; only `--load-sa` counts.
    @Test("ignores rules for anything else")
    func otherRules() {
        let rules = """
            alex ALL=(root) NOPASSWD: sha256:\(Self.stale) /usr/bin/something --else
            alex ALL=(root) NOPASSWD: /opt/homebrew/bin/yabai --install-sa
            """
        #expect(ScriptingAddition.pinnedDigest(in: rules, binary: "/opt/homebrew/bin/yabai") == nil)
    }

    /// sudo also accepts base64 digests. Reading one as if it were hex would
    /// compare two different encodings and cry drift on a working setup.
    @Test("treats a non-hex digest as no rule")
    func base64Digest() {
        let rules =
            "alex ALL=(root) NOPASSWD: sha256:N60VV6fFSmGZ"
            + "p43by+9bYP0CJOXB9ROc+u0A39qkRQE= /opt/homebrew/bin/yabai --load-sa"
        #expect(ScriptingAddition.pinnedDigest(in: rules, binary: "/opt/homebrew/bin/yabai") == nil)
    }

    @Test("an upgraded binary reads as stale, not as working")
    func upgradeGoesStale() throws {
        let fixture = try Fixture(rulePins: Self.stale)
        guard case .hashStale(let pinned, let actual) = fixture.status() else {
            Issue.record("expected the stale pin to be reported")
            return
        }
        #expect(pinned == Self.stale)
        #expect(actual == fixture.digest)
    }

    @Test("a matching pin reads as permitted")
    func matchingPin() throws {
        let fixture = try Fixture()
        #expect(fixture.status() == .permitted)
    }

    @Test("no rule at all is not mistaken for a match")
    func noRule() throws {
        let fixture = try Fixture(writeRule: false)
        #expect(fixture.status() == .ruleMissing)
    }

    @Test("an uninstalled addition is reported before the rule is read")
    func noBundle() throws {
        let fixture = try Fixture(installBundle: false)
        #expect(fixture.status() == .bundleMissing)
    }

    /// The script is assembled into a root shell, so a name that is not a name
    /// must stop it rather than be quoted and hoped about.
    @Test("refuses to build a script around an unexpected user name")
    func refusesOddUser() {
        let digest = String(repeating: "a", count: 64)
        #expect(ScriptingAddition.repairScript(user: "alex'; rm -rf /", digest: digest) == nil)
        #expect(ScriptingAddition.repairScript(user: "", digest: digest) == nil)
        #expect(ScriptingAddition.repairScript(user: "alex", digest: "short") == nil)
        #expect(ScriptingAddition.repairScript(user: "alex", digest: digest) != nil)
    }

    /// visudo has to run before install, or a rule this app got wrong becomes
    /// a sudoers file sudo refuses to parse — which locks the user out of sudo.
    @Test("validates the rule before installing it")
    func validatesBeforeInstalling() throws {
        let script = try #require(
            ScriptingAddition.repairScript(user: "alex", digest: String(repeating: "b", count: 64))
        )
        let validate = try #require(script.range(of: "visudo -cf"))
        let install = try #require(script.range(of: "/usr/bin/install"))
        #expect(validate.lowerBound < install.lowerBound)
    }

    @Test("escapes the script for AppleScript")
    func escaping() {
        let wrapped = ScriptingAddition.appleScript(running: "printf '%s\\n' \"x\"")
        #expect(wrapped.hasPrefix("do shell script \""))
        #expect(wrapped.hasSuffix("\" with administrator privileges"))
        #expect(wrapped.contains("\\\"x\\\""))
    }

    /// A binary, a rule and an installed addition in a directory of their own.
    private struct Fixture {
        let root: URL
        let digest: String
        private let rulesPath: String
        private let bundlePath: String
        private let binaryPath: String

        init(rulePins: String? = nil, writeRule: Bool = true, installBundle: Bool = true) throws {
            root = FileManager.default.temporaryDirectory.appending(path: "sa-\(UUID())")
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let binary = root.appending(path: "yabai")
            try Data("not really yabai, but it hashes".utf8).write(to: binary)
            binaryPath = binary.path
            digest = try #require(ScriptingAddition.digest(ofFileAt: binary.path))

            bundlePath = root.appending(path: "yabai.osax").path
            if installBundle {
                try FileManager.default.createDirectory(
                    at: root.appending(path: "yabai.osax"), withIntermediateDirectories: true)
            }

            rulesPath = root.appending(path: "sudoers").path
            if writeRule {
                let pinned = rulePins ?? digest
                try Data(
                    "alex ALL=(root) NOPASSWD: sha256:\(pinned) \(binaryPath) --load-sa\n".utf8
                ).write(to: URL(fileURLWithPath: rulesPath))
            }
        }

        func status() -> ScriptingAddition.Status {
            ScriptingAddition.status(binary: binaryPath, sudoers: rulesPath, bundle: bundlePath)
        }
    }

    @Test("the repair refuses a binary path that could escape its quoting")
    func repairRejectsUnsafeBinary() {
        let digest = String(repeating: "a", count: 64)
        #expect(
            ScriptingAddition.repairScript(user: "alex", digest: digest, binary: "/opt/a'b") == nil)
        #expect(
            ScriptingAddition.repairScript(user: "alex", digest: digest, binary: "/opt/a b") == nil)
        #expect(
            ScriptingAddition.repairScript(user: "alex", digest: digest, binary: "yabai") == nil)
        #expect(
            ScriptingAddition.repairScript(
                user: "alex", digest: digest, binary: "/opt/homebrew/bin/yabai")
                != nil)
    }
}
