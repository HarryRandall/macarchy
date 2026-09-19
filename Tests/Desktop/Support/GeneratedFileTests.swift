import Foundation
import Testing

@testable import Desktop

/// Generated files are not locked, so the guarantee is that a hand edit is
/// noticed and preserved rather than silently discarded.
@Suite("GeneratedFile")
struct GeneratedFileTests {
    private func sandboxedFile() throws -> (GeneratedFile, URL) {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "macarchy-gen-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        // Own ledger per test: it is shared on-disk state, and these run in parallel.
        return (
            GeneratedFile(
                url: root.appending(path: "testrc"),
                ledgerURL: root.appending(path: "generated.json")),
            root
        )
    }

    @Test("writing then rewriting identical content reports unchanged")
    func identicalContentIsUnchanged() throws {
        let (file, root) = try sandboxedFile()
        defer { try? FileManager.default.removeItem(at: root) }

        #expect(file.write("#!/bin/bash\necho one\n", reason: "t") == .written)
        #expect(file.write("#!/bin/bash\necho one\n", reason: "t") == .unchanged)
    }

    /// launchd executes these; a generated file that is not executable is a
    /// silent boot failure.
    @Test("shebang files stay executable")
    func shebangFilesAreExecutable() throws {
        let (file, root) = try sandboxedFile()
        defer { try? FileManager.default.removeItem(at: root) }

        _ = file.write("#!/bin/bash\necho one\n", reason: "t")
        let mode = try FileManager.default
            .attributesOfItem(atPath: file.url.path)[.posixPermissions] as? Int
        #expect(mode == 0o755)
    }

    @Test("a hand edit is detected and reported")
    func handEditsAreReported() throws {
        let (file, root) = try sandboxedFile()
        defer { try? FileManager.default.removeItem(at: root) }

        _ = file.write("#!/bin/bash\necho one\n", reason: "t")
        #expect(file.hasDrifted == false)

        try "#!/bin/bash\necho EDITED\n".write(to: file.url, atomically: true, encoding: .utf8)
        #expect(file.hasDrifted)

        #expect(file.write("#!/bin/bash\necho two\n", reason: "t").isDrift)
        #expect(file.hasDrifted == false)
    }

    @Test("keep regions survive regeneration")
    func keepRegionsSurvive() throws {
        let (file, root) = try sandboxedFile()
        defer { try? FileManager.default.removeItem(at: root) }

        let content = """
            #!/bin/bash
            echo generated
            \(GeneratedFile.beginKeep) extra
            export MY_OWN_THING=1
            \(GeneratedFile.endKeep)
            """
        _ = file.write(content, reason: "t")
        #expect(file.preservedRegions()["extra"]?.contains("MY_OWN_THING") == true)
    }
}
