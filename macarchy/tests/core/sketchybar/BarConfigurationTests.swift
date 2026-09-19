import Foundation
import Testing
@testable import Macarchy

struct BarConfigurationTests {
    @Test("moving a component preserves all members and changes side together")
    func groupedMove() {
        var config = BarConfiguration()
        config.components = [
            BarComponent(
                id: "spaces", title: "Spaces", side: "left", members: ["space.1", "space.2"]),
            BarComponent(
                id: "cpu", title: "CPU", side: "right", members: ["cpu.icon", "cpu.text"],
                brackets: ["cpu.bracket"])
        ]
        config.move("cpu", before: "spaces")
        #expect(config.components.map(\.id) == ["cpu", "spaces"])
        #expect(config.components[0].side == "left")
        #expect(config.components[0].members == ["cpu.icon", "cpu.text"])
        #expect(config.components[0].brackets == ["cpu.bracket"])
    }

    @Test("right-side query order reverses visual order without separating groups")
    func rightOrder() {
        var config = BarConfiguration()
        config.components = [
            BarComponent(id: "cpu", title: "CPU", side: "right", members: ["cpu.icon", "cpu.text"]),
            BarComponent(id: "clock", title: "Clock", side: "right", members: ["calendar"])
        ]
        let args = BarCommands.settings(config)
        let moves = args.enumerated().filter { $0.element == "--move" }.map {
            Array(args[$0.offset...($0.offset + 3)])
        }
        #expect(
            moves == [
                ["--move", "cpu.text", "after", "calendar"],
                ["--move", "cpu.icon", "after", "cpu.text"]
            ])
    }

    @Test("startup restores custom components and treats text as literal data")
    func startupReplay() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let log = directory.appending(path: "arguments")
        let spy = directory.appending(path: "sketchybar")
        let marker = directory.appending(path: "should-not-exist")
        let script =
            "#!/bin/bash\nif [ \"$1\" = --query ]; then exit 1; fi\nprintf '%s\\0' \"$@\" >> \(BarCommands.quote(log.path))\n"
        try script.write(to: spy, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: spy.path)
        var component = BarComponent(
            id: "macarchy.test", title: "Text", side: "right", members: ["macarchy.test"])
        component.kind = "text"
        component.text = "Harry's $(touch \(marker.path))\n--remove calendar"
        var config = BarConfiguration()
        config.components = [component]
        let replay = BarCommands.startupScript(config).replacingOccurrences(
            of: BarCommands.quote(Paths.sketchybar), with: BarCommands.quote(spy.path))
        let url = directory.appending(path: "replay.sh")
        try replay.write(to: url, atomically: true, encoding: .utf8)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [url.path]
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
        let arguments = try String(contentsOf: log, encoding: .utf8).split(separator: "\0").map(
            String.init)
        #expect(arguments.contains("label=\(component.text)"))
        #expect(arguments.prefix(4) == ["--add", "item", "macarchy.test", "right"])
        #expect(!FileManager.default.fileExists(atPath: marker.path))
        let decoded = try JSONDecoder().decode(
            BarConfiguration.self, from: JSONEncoder().encode(config))
        #expect(decoded == config)
    }

    @Test("visible workspaces keep their context-dependent drawing flags on startup")
    func workspaceDrawing() {
        var config = BarConfiguration()
        config.components = [
            BarComponent(
                id: "workspaces", title: "Workspaces", side: "left",
                members: ["space.1", "space.2"], drawing: ["space.1": true, "space.2": false])
        ]
        #expect(!BarCommands.settings(config, startup: true).contains("drawing=on"))
        config.components[0].visible = false
        #expect(BarCommands.settings(config, startup: true).contains("updates=off"))
        #expect(BarCommands.settings(config, startup: true).contains("drawing=off"))
    }
    @Test("uniform spacing replaces legacy spacers and uses the same edge padding")
    func uniformSpacing() {
        var config = BarConfiguration()
        config.components = [
            BarComponent(
                id: "cpu", title: "CPU", side: "right", members: ["gap.cpu", "cpu.icon", "cpu.text"]
            ),
            BarComponent(id: "clock", title: "Clock", side: "right", members: ["calendar"])
        ]
        config.componentPadding = 8
        config.componentSpacing = 12
        let args = BarCommands.settings(config)
        #expect(args.contains("width=0"))
        #expect(args.filter { $0 == "padding_left=8.0" }.count == 2)
        #expect(args.filter { $0 == "padding_right=20.0" }.count == 2)
        #expect(BarCommands.startupScript(config).contains("padding_right=20.0"))
    }

    @Test("multiple groups keep their order when dragged and overrides survive replay")
    func bulkMoveAndSpacing() throws {
        var config = BarConfiguration()
        config.components = ["cpu", "ram", "battery", "clock"].map {
            BarComponent(id: $0, title: $0, side: "right", members: [$0])
        }
        config.move(["cpu", "ram"], before: "clock")
        #expect(config.components.map(\.id) == ["battery", "cpu", "ram", "clock"])
        config.components[1].paddingOverride = 0
        config.components[1].spacingOverride = 1
        let args = BarCommands.settings(config)
        #expect(args.contains("padding_left=0.0"))
        #expect(args.contains("padding_right=1.0"))
        let decoded = try JSONDecoder().decode(
            BarConfiguration.self, from: JSONEncoder().encode(config))
        #expect(decoded == config)
        config.move(["cpu", "ram"], before: "ram")
        #expect(config.components.map(\.id) == ["battery", "cpu", "ram", "clock"])
    }

}

private extension BarCommands {
    static func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func startupScript(_ configuration: BarConfiguration) -> String {
        var lines = ["#!/bin/bash", "# Generated menu bar component overrides."]
        for component in configuration.components where component.isCustom {
            let query = ([Paths.sketchybar, "--query", component.id]).map(quote).joined(
                separator: " ")
            let add = ([Paths.sketchybar] + customArguments(component)).map(quote).joined(
                separator: " ")
            lines.append("\(query) >/dev/null 2>&1 || \(add)")
        }
        let args = settings(configuration, startup: true)
        if !args.isEmpty {
            lines.append(([Paths.sketchybar] + args).map(quote).joined(separator: " "))
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
