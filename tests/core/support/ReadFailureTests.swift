import Foundation
import Testing

@testable import Macarchy

struct ReadFailureTests {
    func temporary() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "macarchy-read-failure-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @Test func folderInPlaceOfFileSaysSo() throws {
        let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appending(path: "skhdrc")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let message = #expect(throws: (any Error).self) {
            try String(contentsOf: url, encoding: .utf8)
        }.map { ReadFailure.describe($0, at: url) }
        #expect(message?.contains("is a folder") == true, "\(message ?? "")")
        #expect(message?.contains("skhdrc") == true)
    }

    @Test func unreadableSettingsNameTheFileWithStraightPunctuation() throws {
        let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appending(path: "settings.json")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let error = #expect(throws: ConfigurationError.self) {
            try SettingsStore(url: url).read()
        }
        let message = error?.message ?? ""
        #expect(message.contains("settings.json is a folder"), "\(message)")
        #expect(!message.contains("\u{2019}") && !message.contains("\u{201C}"))
    }

    @Test func truncatedJSONEndsInOneFullStop() throws {
        let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appending(path: "settings.json")
        try #"{ "schema": 1, "currentTheme": "#.write(to: url, atomically: true, encoding: .utf8)
        let error = #expect(throws: ConfigurationError.self) {
            try SettingsStore(url: url).read()
        }
        let message = error?.message ?? ""
        #expect(message.contains("settings.json is not valid JSON: "), "\(message)")
        #expect(message.hasSuffix(".") && !message.hasSuffix(".."), "\(message)")
    }

    @Test func systemTextLosesCurlyQuotes() {
        #expect(
            ReadFailure.sentence("The file \u{201C}a\u{201D} couldn\u{2019}t be opened")
                == "The file \"a\" couldn't be opened.")
    }
}
