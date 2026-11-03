import Foundation
import Testing

@testable import Macarchy

/// The skhdrc a new install is seeded with, read from the repository.
@Suite("Default shortcuts")
struct DefaultShortcutsTests {
    static let skhd = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "resources/integrations/skhd")

    private func bindings() throws -> [SkhdBinding] {
        SkhdConfig.parse(
            try String(contentsOf: Self.skhd.appending(path: "skhdrc"), encoding: .utf8))
    }

    @Test("every binding parses, under its own heading, with no chord taken twice")
    func parses() throws {
        let bindings = try bindings()
        #expect(bindings.count == 47)
        #expect(bindings.allSatisfy { $0.section != nil && !$0.isDisabled })
        let chords = bindings.map { Set($0.modifiers).sorted() + [$0.key.lowercased()] }
        #expect(Set(chords).count == chords.count)
    }

    @Test("Control reaches every desktop and Command is left to the app shortcuts")
    func modifiers() throws {
        let bindings = try bindings()
        for number in 1...10 {
            let key = String(number % 10)
            #expect(
                bindings.contains {
                    $0.modifiers == ["ctrl"] && $0.key == key
                        && $0.command == "macarchy space \(number)"
                })
            #expect(
                bindings.contains {
                    $0.modifiers == ["ctrl", "shift"] && $0.key == key
                        && $0.command.hasSuffix("move-window-to-space.sh\" \(number)")
                })
        }
        let command = bindings.filter { $0.modifiers.contains("cmd") }.map(\.key)
        #expect(command.sorted() == ["m", "q", "w"])
        #expect(!bindings.contains { $0.modifiers.contains("alt") })
    }

    /// The defaults reach their scripts through the app link, so each must ship.
    @Test("every script a binding runs ships with the app and can run")
    func scripts() throws {
        let link =
            "\"$HOME/Library/Application Support/Macarchy/Macarchy.app/Contents/Resources/skhd/"
        let commands = try bindings().flatMap { [$0.command] + $0.appOverrides.map(\.command) }
        let scripts = Set(commands.filter { $0.contains("/scripts/") })
        #expect(scripts.count == 13)
        for command in scripts {
            #expect(command.hasPrefix(link + "scripts/"))
            let name = String(command.dropFirst(link.count).prefix { $0 != "\"" })
            let file = Self.skhd.appending(path: name)
            #expect(FileManager.default.isExecutableFile(atPath: file.path), "\(name)")
        }
    }
}
