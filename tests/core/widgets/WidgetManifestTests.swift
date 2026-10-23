import Foundation
import Testing

@testable import Macarchy

@Suite("Widget manifests")
struct WidgetManifestTests {
    static let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    static let builtIn = repository.appending(path: "resources/widgets")

    private func check(_ json: String, folder: URL? = nil) -> WidgetCheck {
        WidgetManifest.check(data: Data(json.utf8), folder: folder)
    }

    private func messages(_ json: String) -> [String] {
        check(json).problems.map(\.message)
    }

    /// A valid manifest with `extra` lines added after the required fields.
    private func manifest(_ extra: String = "") -> String {
        """
        {
          "schema": 1,
          "id": "test",
          "name": "Test",
          "version": "1.0.0"\(extra.isEmpty ? "" : ",\n" + extra)
        }
        """
    }

    @Test("every built-in widget passes its own check", arguments: ["clock", "cpu", "battery"])
    func builtIns(id: String) throws {
        let check = WidgetManifest.check(folder: Self.builtIn.appending(path: id))
        #expect(check.problems.isEmpty, "\(check.problems)")
        let manifest = try #require(check.manifest)
        #expect(manifest.id == id)
        #expect(!manifest.isScripted)
        #expect(manifest.click?.dropdown?.isEmpty == false)
    }

    @Test("settings keep the order they were written in")
    func settingsOrder() throws {
        let clock = try #require(
            WidgetManifest.check(folder: Self.builtIn.appending(path: "clock")).manifest)
        #expect(clock.orderedSettings.first?.key == "weekday")
        #expect(clock.orderedSettings.last?.key == "format")
        #expect(clock.orderedSettings.count == clock.settings?.count)
    }

    @Test("a manifest with only the required fields is fine")
    func minimal() {
        #expect(check(manifest()).ok)
    }

    @Test("a missing required field is named, with its line")
    func missing() {
        let problems = check("{\n  \"schema\": 1,\n  \"name\": \"X\",\n  \"version\": \"1.0.0\"\n}")
            .problems
        #expect(problems == [WidgetProblem(line: 1, message: "id is missing")])
    }

    @Test("a value of the wrong kind says what it should be")
    func wrongKind() {
        let problems = check(manifest("  \"update\": { \"events\": \"system_woke\" }")).problems
        #expect(problems == [WidgetProblem(line: 6, message: "update.events should be a list")])
    }

    @Test("an update interval written loosely gets the sentence from the design")
    func interval() {
        let problems = check(manifest("  \"update\": { \"every\": \"1 sec\" }")).problems
        #expect(
            problems == [
                WidgetProblem(
                    line: 6,
                    message: "update.every should look like 1s, 5m or minute, not \"1 sec\"")
            ])
        #expect(
            messages(manifest("  \"update\": { \"every\": \"stream\" }"))
                == ["update.every cannot be stream yet; use an interval such as 2s"])
    }

    @Test("a misspelt key is pointed out with what was probably meant")
    func typo() {
        #expect(
            messages(manifest("  \"upate\": {}"))
                == ["upate is not something a widget.json can contain; did you mean update?"])
        #expect(
            messages(manifest("  \"style\": { \"boxx\": \"fill\" }"))
                == ["boxx is not something a widget.json can contain; did you mean box?"])
    }

    @Test("ids, names and versions are checked")
    func identity() {
        let problems = messages(
            """
            {
              "schema": 2,
              "id": "Not OK",
              "name": " ",
              "version": "1.0"
            }
            """)
        #expect(
            problems == [
                "schema should be 1, the only version this Macarchy reads",
                "id should be lower-case letters, numbers and hyphens, up to 40 characters",
                "name is empty",
                "version should look like 1.0.0"
            ])
    }

    @Test("a source and a provider cannot both be set, and sources are from a fixed list")
    func source() {
        #expect(
            messages(manifest("  \"source\": \"weather\""))
                == [
                    "source \"weather\" is not a reading Macarchy provides; use one of date, battery, cpu"
                ])
        #expect(
            messages(manifest("  \"source\": \"date\",\n  \"provider\": \"provider.sh\""))
                == ["a widget has a source or a provider, not both"])
    }

    @Test("settings are checked against their type")
    func settings() {
        let problems = messages(
            manifest(
                """
                  "settings": {
                    "order": { "type": "choice", "label": "Order", "options": ["a", "b"], "default": "c" },
                    "size": { "type": "number", "label": "Size", "min": 1, "max": 10, "default": 20 },
                    "tint": { "type": "colour", "label": "Tint", "default": "blue" },
                    "flag": { "type": "toggle", "label": "Flag", "options": ["x"] },
                    "Bad": { "type": "text", "label": "Bad" },
                    "what": { "type": "slider", "label": "What" }
                  }
                """))
        #expect(
            Set(problems)
                == [
                    "order.default should be one of a, b",
                    "size.default should be at most 10",
                    "tint.default should be a colour such as #a5b4fc",
                    "options only applies to choice settings",
                    "setting names start with a lower-case letter and use only letters and numbers",
                    "what.type should be one of text, number, toggle, choice, colour, format"
                ])
    }

    @Test("a click does one thing, and dropdown rows have what their type needs")
    func click() {
        #expect(
            messages(manifest("  \"click\": { \"open\": \"Calendar\", \"run\": \"date\" }"))
                == ["click should have one of open, run or dropdown"])
        let problems = messages(
            manifest(
                """
                  "settings": { "big": { "type": "toggle", "label": "Big" } },
                  "click": { "dropdown": [
                    { "type": "action", "label": "Both", "run": "a", "open": "b" },
                    { "type": "toggle", "label": "Size", "setting": "small" },
                    { "type": "reading", "label": "Load" },
                    { "type": "divider", "label": "Line" },
                    { "type": "heading", "label": "{unclosed" },
                    { "type": "toggle", "label": "Big", "setting": "big" }
                  ] }
                """))
        #expect(
            problems == [
                "dropdown row 1 needs one of run or open",
                "dropdown row 2 changes small, which is not a toggle setting",
                "dropdown row 3 needs a value",
                "dropdown row 4 is a divider, which has nothing else",
                "dropdown row 5 label has a { that is never closed"
            ])
    }

    @Test("anything that runs a command makes the widget a scripted one")
    func scripted() throws {
        var manifest = WidgetManifest(id: "x", name: "X")
        #expect(!manifest.isScripted)
        manifest.click = WidgetClick(dropdown: [WidgetMenuRow(type: "action", label: "Go")])
        #expect(!manifest.isScripted)
        manifest.click?.dropdown?[0].run = "say hi"
        #expect(manifest.isScripted)
        manifest.click = WidgetClick(run: "date")
        #expect(manifest.isScripted)
        manifest.click = nil
        manifest.provider = "provider.sh"
        #expect(manifest.isScripted)
    }

    @Test("a provider must be in the folder and executable")
    func provider() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "widget-\(UUID())/test")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
        let json = manifest("  \"provider\": \"provider.sh\"")
        #expect(
            check(json, folder: folder).problems.map(\.message)
                == ["provider.sh is not in the widget's folder"])
        let script = folder.appending(path: "provider.sh")
        try Data("#!/bin/sh\necho hi\n".utf8).write(to: script)
        #expect(
            check(json, folder: folder).problems.map(\.message)
                == ["provider.sh is not executable; run chmod +x provider.sh"])
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        #expect(check(json, folder: folder).ok)
        #expect(
            messages(manifest("  \"provider\": \"../escape.sh\""))
                == ["provider should be a file in the widget's folder, such as provider.sh"])
    }

    @Test("the folder name and the id must agree")
    func folderName() {
        let folder = URL(fileURLWithPath: "/tmp/widgets/other")
        #expect(
            check(manifest(), folder: folder).problems.map(\.message)
                == ["id is \"test\" but the folder is called \"other\"; they should match"])
    }

    @Test("saved instance settings are checked against the widget")
    func instanceSettings() throws {
        let clock = try #require(
            WidgetManifest.check(folder: Self.builtIn.appending(path: "clock")).manifest)
        #expect(
            clock.problems(settings: ["seconds": .bool(true), "order": .text("month-day")]).isEmpty)
        #expect(
            clock.problems(settings: [
                "seconds": .text("yes"), "order": .text("sideways"), "colour": .text("#fff")
            ])
                == [
                    "colour is not a setting of Clock",
                    "order should be one of day-month, month-day",
                    "seconds should be true or false"
                ])
    }

    @Test(
        "intervals convert to seconds",
        arguments: [
            ("2s", 2), ("5m", 300), ("1h", 3600), ("minute", 60), ("second", 1)
        ])
    func seconds(every: String, seconds: Int) {
        #expect(WidgetUpdate(every: every).seconds == seconds)
    }

    @Test("the published JSON Schema names the same fields the checker reads")
    func schema() throws {
        let data = try Data(contentsOf: Self.builtIn.appending(path: "widget.schema.json"))
        let schema = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        func keys(_ object: Any?) -> Set<String> {
            let properties = (object as? [String: Any])?["properties"] as? [String: Any]
            return Set(properties?.keys ?? [:].keys)
        }
        let properties = try #require(schema["properties"] as? [String: Any])
        let definitions = try #require(schema["$defs"] as? [String: Any])
        #expect(keys(schema) == Set(WidgetManifest.CodingKeys.allCases.map(\.rawValue)))
        #expect(keys(properties["style"]) == Set(WidgetStyle.CodingKeys.allCases.map(\.rawValue)))
        #expect(keys(properties["update"]) == Set(WidgetUpdate.CodingKeys.allCases.map(\.rawValue)))
        #expect(keys(properties["click"]) == Set(WidgetClick.CodingKeys.allCases.map(\.rawValue)))
        #expect(
            keys(definitions["setting"]) == Set(WidgetSetting.CodingKeys.allCases.map(\.rawValue)))
        #expect(keys(definitions["row"]) == Set(WidgetMenuRow.CodingKeys.allCases.map(\.rawValue)))
    }
}
