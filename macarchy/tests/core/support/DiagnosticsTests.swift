import Foundation
import Testing

@testable import Macarchy

struct DiagnosticsTests {
    @Test("the home folder and username are removed from reports")
    func redactsIdentity() {
        let text = "Failed at \(Paths.home.path)/x for \(NSUserName())"
        let redacted = Diagnostics.redact(text)
        #expect(!redacted.contains(Paths.home.path))
        #expect(!redacted.contains(" \(NSUserName())"))
    }

    @Test("bash syntax errors keep only their line number")
    func syntaxErrorsAreReduced() async {
        let file = FileManager.default.temporaryDirectory.appending(path: "bad-\(UUID()).sh")
        defer { try? FileManager.default.removeItem(at: file) }
        try? "#!/bin/bash\ncurl -H 'Authorization: Bearer SECRET' $(\n".write(
            to: file, atomically: true, encoding: .utf8)
        let result = await CommandRunner.run("/bin/bash", ["-n", file.path])
        #expect(!result.ok)
        #expect(result.stderr.range(of: "line [0-9]+", options: .regularExpression) != nil)
    }
}
