import Foundation
import Testing

@testable import Macarchy

@Suite("Widget output")
struct WidgetOutputTests {
    @Test("JSON is read field by field, with American spellings accepted")
    func json() {
        let output = WidgetOutput.parse(
            ##"{"label": "24:13", "icon": "⏱", "color": "#a5b4fc", "values": {"left": 24, "on": true}, "drawing": false}"##
        )
        #expect(output.label == "24:13" && output.icon == "⏱")
        #expect(output.colour == "#a5b4fc")
        #expect(output.values == ["left": "24", "on": "true"])
        #expect(output.drawing == false)
    }

    @Test("plain text is the label, on one line")
    func text() {
        #expect(WidgetOutput.parse(" 3 users\n load 1.2 \n").label == "3 users load 1.2")
        #expect(WidgetOutput.parse("{not json").label == "{not json")
    }

    @Test("templates fill what they can and leave the rest as written")
    func template() {
        let values = ["load": "42%", "temp": "61°"]
        #expect(WidgetTemplate.render("{load} {temp}", values: values) == "42% 61°")
        #expect(WidgetTemplate.render("CPU {lod}", values: values) == "CPU {lod}")
        #expect(WidgetTemplate.render("open {load", values: values) == "open {load")
    }

    @Test("colours become SketchyBar's 0xaarrggbb")
    func colours() {
        #expect(WidgetColour.sketchybar("#A5B4FC") == "0xffa5b4fc")
        #expect(WidgetColour.sketchybar("#a5b4fc80") == "0x80a5b4fc")
        #expect(WidgetColour.sketchybar("red") == nil)
    }
}

@Suite("Widget provider runner")
struct WidgetProviderRunnerTests {
    private func folder(_ script: String) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appending(path: "provider-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let path = folder.appending(path: "provider.sh")
        try Data(script.utf8).write(to: path)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path.path)
        return folder
    }

    @Test("a provider gets its settings and runs from its folder")
    func runs() async throws {
        let folder = try folder(
            """
            #!/bin/sh
            printf '{"label": "%s %s %s"}' "$MACARCHY_SETTING_TWENTY_FOUR_HOUR" "$MACARCHY_INSTANCE" "$(basename "$PWD")"
            """)
        defer { try? FileManager.default.removeItem(at: folder) }
        let result = await WidgetProviderRunner().run(
            provider: "provider.sh", in: folder, instance: "macarchy.test", widget: "test",
            settings: ["twentyFourHour": .bool(true)])
        #expect(try result.get().label == "true macarchy.test \(folder.lastPathComponent)")
    }

    @Test("a failing provider reports the first line of what it printed to stderr")
    func fails() async throws {
        let folder = try folder("#!/bin/sh\necho 'no network' >&2\necho more >&2\nexit 3\n")
        defer { try? FileManager.default.removeItem(at: folder) }
        let result = await WidgetProviderRunner().run(
            provider: "provider.sh", in: folder, instance: "x", widget: "x", settings: [:])
        #expect(result == .failure(.failed(status: 3, message: "no network")))
    }

    @Test("a provider that hangs is reported as stopped")
    func timesOut() async {
        let runner = WidgetProviderRunner(timeout: 2) { executable, _, _, _ in
            CommandResult(command: executable, status: -1, stderr: "Timed out: provider.sh")
        }
        let result = await runner.run(
            provider: "provider.sh", in: URL(fileURLWithPath: "/tmp"), instance: "x", widget: "x",
            settings: [:])
        #expect(result == .failure(.timedOut(seconds: 2)))
        #expect(
            "\(WidgetProviderRunner.Failure.timedOut(seconds: 2))"
                == "took longer than 2 seconds and was stopped")
    }

    @Test("the environment carries settings and a known PATH, and nothing else inherited")
    func environment() {
        let environment = WidgetProviderRunner.environment(
            instance: "macarchy.clock", widget: "clock", settings: ["leadingZero": .bool(false)],
            inherited: ["HOME": "/Users/test", "LANG": "en_GB.UTF-8", "API_TOKEN": "secret"])
        #expect(environment["MACARCHY_SETTING_LEADING_ZERO"] == "false")
        #expect(environment["PATH"] == WidgetProviderRunner.path)
        #expect(environment["HOME"] == "/Users/test" && environment["LANG"] == "en_GB.UTF-8")
        #expect(environment["API_TOKEN"] == nil)
    }
}
