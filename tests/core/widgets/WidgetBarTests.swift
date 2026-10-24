import Foundation
import Testing

@testable import Macarchy

private struct Call {
    let executable: String
    let arguments: [String]
    let environment: [String: String]?
    let directory: URL?
}

private actor CallRecorder {
    var calls: [Call] = []

    func record(
        _ executable: String, _ arguments: [String], _ environment: [String: String]?,
        _ directory: URL?
    ) -> CommandResult {
        calls.append(
            Call(
                executable: executable, arguments: arguments, environment: environment,
                directory: directory))
        return CommandResult(command: executable, status: arguments.first == "--query" ? 1 : 0)
    }

    func executables() -> [String] { calls.map(\.executable) }
    func arguments() -> [[String]] { calls.map(\.arguments) }
    func last() -> Call? { calls.last }
}

@Suite("Widgets on the bar")
struct WidgetBarTests {
    private func widget(click: WidgetClick? = nil, style: WidgetStyle? = nil) -> WidgetManifest {
        var manifest = WidgetManifest(id: "clock", name: "Clock")
        manifest.icon = "􀧞"
        manifest.click = click
        manifest.style = style
        return manifest
    }

    private func instance(_ id: String = "macarchy.clock") -> BarComponent {
        var component = BarComponent(id: id, title: "Clock", side: "right", members: [id])
        component.widget = "clock"
        return component
    }

    @Test("a widget's item gets its icon, look and click from the manifest")
    func look() {
        var style = WidgetStyle()
        style.box = "outline"
        style.size = 13
        style.radius = 6
        style.iconColour = "accent"
        style.textColour = "#a5b4fc"
        let look = WidgetLook(
            manifests: ["clock": widget(click: WidgetClick(open: "Calendar"), style: style)],
            accent: "0xffbfa75d")
        let arguments = look.arguments(for: instance())
        #expect(arguments.prefix(2) == ["--set", "macarchy.clock"])
        #expect(arguments.contains("icon=􀧞"))
        #expect(arguments.contains("label.font=SF Pro:Semibold:13"))
        #expect(arguments.contains("background.border_width=1"))
        #expect(arguments.contains("background.corner_radius=6"))
        #expect(arguments.contains("icon.color=0xffbfa75d"))
        #expect(arguments.contains("label.color=0xffa5b4fc"))
        #expect(
            arguments.contains("click_script=\(Paths.cliInShell) widget click 'macarchy.clock'"))
    }

    @Test("the component's edits to the look and click go over the widget's own")
    func edited() {
        var style = WidgetStyle()
        style.box = "outline"
        style.size = 13
        let look = WidgetLook(manifests: ["clock": widget(style: style)])
        var component = instance()
        component.style = WidgetStyle()
        component.style?.box = "fill"
        component.click = WidgetClick(open: "Calendar")
        let arguments = look.arguments(for: component)
        #expect(arguments.contains("label.font=SF Pro:Semibold:13"))
        #expect(!arguments.contains("background.border_width=1"))
        #expect(
            arguments.contains("click_script=\(Paths.cliInShell) widget click 'macarchy.clock'"))
    }

    @Test(
        "a widget with nothing to click clears any click script, and an unknown widget is left alone"
    )
    func noClick() {
        let look = WidgetLook(manifests: ["clock": widget()])
        #expect(look.arguments(for: instance()).contains("click_script="))
        #expect(WidgetLook().arguments(for: instance()).isEmpty)
    }

    @Test("muted follows the theme's text colour, dimmed, and text sets nothing")
    func themeColours() {
        let look = WidgetLook(accent: "0xff112233", muted: "0x99dacbe6")
        #expect(look.colour("muted") == "0x99dacbe6")
        #expect(look.colour("text") == nil)
        #expect(look.colour("#000000") == "0xff000000")
    }

    @Test("the component's own colour overrides the widget's, because it comes after")
    func overrides() {
        var component = instance()
        component.colour = "0xff00ff00"
        var style = WidgetStyle()
        style.textColour = "#ff0000"
        var configuration = BarConfiguration()
        configuration.components = [component]
        let arguments = BarCommands.settings(
            configuration, widgets: WidgetLook(manifests: ["clock": widget(style: style)]))
        let widgetColour = arguments.firstIndex(of: "label.color=0xffff0000")
        let override = arguments.lastIndex(of: "label.color=0xff00ff00")
        #expect(widgetColour != nil && override != nil)
        #expect((widgetColour ?? 0) < (override ?? 0))
    }

    @Test("startup adds a widget's item when the bar does not have it")
    func replay() async throws {
        let recorder = CallRecorder()
        var configuration = BarConfiguration()
        configuration.components = [instance()]
        try await BarCommands.replay(
            configuration,
            integrations: Integrations { executable, arguments in
                await recorder.record(executable, arguments, nil, nil)
            },
            widgets: WidgetLook(manifests: ["clock": widget()]))
        let calls = await recorder.arguments()
        #expect(calls[0] == ["--query", "macarchy.clock"])
        #expect(calls[1] == ["--add", "item", "macarchy.clock", "right"])
        #expect(calls[2].contains("icon=􀧞"))
    }

    @Test("a two-line widget is an icon, a lines item and a box around them")
    func stacked() async throws {
        var style = WidgetStyle()
        style.lines = 2
        style.box = "outline"
        var manifest = widget(style: style)
        manifest.samples = WidgetSamples(widest: "100.0%\n99.9°")
        let look = WidgetLook(manifests: ["clock": manifest])
        var configuration = BarConfiguration()
        configuration.components = [instance()]
        let normalised = look.normalised(configuration)
        #expect(normalised.components[0].members == ["macarchy.clock", "macarchy.clock.lines"])
        #expect(normalised.components[0].brackets == ["macarchy.clock.box"])
        try normalised.validate()
        let arguments = look.arguments(for: normalised.components[0])
        let targets = arguments.indices.filter { arguments[$0] == "--set" }.map {
            arguments[$0 + 1]
        }
        #expect(targets == ["macarchy.clock", "macarchy.clock.lines", "macarchy.clock.box"])
        // The column fits the widest sample, with the box's inset after it.
        #expect(arguments.contains("width=44") && arguments.contains("label.padding_right=-36"))
        #expect(arguments.contains("padding_left=3") && arguments.contains("padding_right=3"))
        #expect(arguments.contains("background.border_width=1"))

        let recorder = CallRecorder()
        try await BarCommands.replay(
            configuration,
            integrations: Integrations { executable, arguments in
                await recorder.record(executable, arguments, nil, nil)
            },
            widgets: look)
        let calls = await recorder.arguments()
        #expect(calls.contains(["--add", "item", "macarchy.clock.lines", "right"]))
        #expect(
            calls.contains([
                "--add", "bracket", "macarchy.clock.box", "macarchy.clock", "macarchy.clock.lines"
            ]))
    }

    @Test("a widget's items must be the shape its layout needs")
    func stackedShape() {
        var component = instance()
        component.members = ["macarchy.clock", "macarchy.other"]
        var configuration = BarConfiguration()
        configuration.components = [component]
        #expect(throws: ConfigurationError.self) { try configuration.validate() }
    }

    @Test("a widget item's id must be safe to put in its click command")
    func unsafeID() {
        var configuration = BarConfiguration()
        configuration.components = [instance("macarchy.clock; rm -rf ~")]
        #expect(throws: ConfigurationError.self) { try configuration.validate() }
    }

    // MARK: - Clicks

    private func click(
        _ click: WidgetClick?, edited: WidgetClick? = nil, recorder: CallRecorder
    ) async throws -> WidgetActions.Outcome {
        var component = instance()
        component.click = edited
        var configuration = BarConfiguration()
        configuration.components = [component]
        let snapshot = WidgetCatalogue.Snapshot(
            entries: [
                .init(
                    id: "clock", directory: URL(fileURLWithPath: "/widgets/clock"),
                    manifest: widget(click: click), origin: .user)
            ], problems: [:])
        return try await WidgetActions.click(
            "macarchy.clock", configuration: configuration, catalogue: snapshot
        ) { executable, arguments, environment, directory in
            await recorder.record(executable, arguments, environment, directory)
        }
    }

    @Test("clicking opens an app by name, or a URL as a URL")
    func opens() async throws {
        let recorder = CallRecorder()
        #expect(
            try await click(WidgetClick(open: "Calendar"), recorder: recorder)
                == .opened("Calendar"))
        let settings = "x-apple.systempreferences:com.apple.Battery-Settings.extension"
        _ = try await click(WidgetClick(open: settings), recorder: recorder)
        #expect(await recorder.arguments() == [["-a", "Calendar"], [settings]])
        #expect(await recorder.executables() == [WidgetActions.openTool, WidgetActions.openTool])
    }

    @Test("clicking runs a command from the widget's folder with its settings")
    func runs() async throws {
        let recorder = CallRecorder()
        #expect(try await click(WidgetClick(run: "say hi"), recorder: recorder) == .ran("say hi"))
        let call = try #require(await recorder.last())
        #expect(call.executable == "/bin/sh" && call.arguments == ["-c", "say hi"])
        #expect(call.environment?["MACARCHY_INSTANCE"] == "macarchy.clock")
        #expect(call.directory?.lastPathComponent == "clock")
    }

    @Test("a dropdown, the widget's own or an edited one, is handed to the app")
    func dropdowns() async throws {
        let recorder = CallRecorder()
        let rows = [WidgetMenuRow(type: "divider")]
        #expect(
            try await click(WidgetClick(dropdown: rows), recorder: recorder)
                == .dropdown("macarchy.clock"))
        #expect(
            try await click(nil, edited: WidgetClick(dropdown: rows), recorder: recorder)
                == .dropdown("macarchy.clock"))
        #expect(try await click(nil, recorder: recorder) == .nothing)
        #expect(await recorder.arguments().isEmpty)
        #expect(
            try await click(
                WidgetClick(dropdown: rows), edited: WidgetClick(open: "Calendar"),
                recorder: recorder) == .opened("Calendar"))
    }

    @Test("clicking something that is not on the bar says so")
    func unknown() async {
        await #expect(throws: ConfigurationError.self) {
            _ = try await WidgetActions.click(
                "macarchy.nothing", configuration: nil,
                catalogue: WidgetCatalogue.Snapshot(entries: [], problems: [:]))
        }
    }
}
