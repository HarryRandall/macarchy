import Foundation
import Testing
@testable import Macarchy

@Suite("Border exclusions")
struct BorderExclusionTests {
    @Test("new configurations start with iPhone Mirroring excluded")
    func initialExclusion() {
        #expect(BorderAppearance().excludedApps == ["iPhone Mirroring"])
        #expect(
            BorderCommand.arguments(values: [:], theme: nil).contains("blacklist=iPhone Mirroring"))
    }

    @Test("removing the initial exclusion survives settings encoding and command generation")
    func removedExclusion() throws {
        var settings = SettingsDocument()
        settings.mergeLegacy(["BORDERS_BLACKLIST": ""])
        let restored = try JSONDecoder().decode(
            SettingsDocument.self, from: JSONEncoder().encode(settings))
        #expect(restored.legacyValues["BORDERS_BLACKLIST"]?.isEmpty == true)
        #expect(
            BorderCommand.arguments(values: restored.legacyValues, theme: nil).contains(
                "blacklist="))
    }

    @Test("custom exclusions do not reinsert iPhone Mirroring")
    func customExclusions() {
        let arguments = BorderCommand.arguments(
            values: ["BORDERS_BLACKLIST": "Messages,FaceTime"], theme: nil)
        #expect(arguments.contains("blacklist=Messages,FaceTime"))
    }
}
