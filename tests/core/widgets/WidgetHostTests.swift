import Foundation
import Testing

@testable import Macarchy

/// Records what the host sends to SketchyBar, and can make a call fail.
private actor SketchybarSpy {
    var calls: [[String]] = []
    var failNext = false

    func run(_ arguments: [String]) -> CommandResult {
        calls.append(arguments)
        defer { failNext = false }
        return CommandResult(command: "sketchybar", status: failNext ? 1 : 0)
    }

    func failOnce() { failNext = true }
    func recorded() -> [[String]] { calls }
}

/// What each widget's provider prints next, by widget id.
private actor ProviderScript {
    var outputs: [String: CommandResult] = [:]
    var runs: [String] = []

    func set(_ widget: String, _ stdout: String, status: Int32 = 0) {
        outputs[widget] = CommandResult(
            command: widget, status: status, stdout: stdout, stderr: status == 0 ? "" : "broke")
    }

    func run(_ widget: String) -> CommandResult {
        runs.append(widget)
        return outputs[widget] ?? CommandResult(command: widget, status: 0)
    }

    func ran() -> [String] { runs }
}

@Suite("Widget host")
struct WidgetHostTests {
    private let spy = SketchybarSpy()
    private let script = ProviderScript()
    private let start = Date(timeIntervalSince1970: 1_000_000_000)

    private func manifest(
        _ id: String, every: String? = nil, events: [String]? = nil, label: String? = nil
    ) -> WidgetManifest {
        var manifest = WidgetManifest(id: id, name: id.capitalized)
        manifest.provider = "provider.sh"
        manifest.update = WidgetUpdate(every: every, events: events)
        manifest.label = label
        manifest.samples = WidgetSamples(unavailable: "…")
        manifest.settings = [
            "unit": WidgetSetting(type: "text", label: "Unit", default: .text("%"))
        ]
        return manifest
    }

    private func host(_ manifests: [WidgetManifest], hidden: Set<String> = []) -> WidgetHost {
        var configuration = BarConfiguration()
        configuration.components = manifests.map { manifest in
            let id = "macarchy.\(manifest.id)"
            var component = BarComponent(
                id: id, title: manifest.name, side: "right", members: [id],
                visible: !hidden.contains(manifest.id))
            component.widget = manifest.id
            return component
        }
        let entries = manifests.map {
            WidgetCatalogue.Entry(
                id: $0.id, directory: URL(fileURLWithPath: "/widgets/\($0.id)"), manifest: $0,
                origin: .user)
        }
        let snapshot = WidgetCatalogue.Snapshot(entries: entries, problems: [:])
        let bar = configuration
        let script = self.script
        let spy = self.spy
        return WidgetHost(
            integrations: Integrations { _, arguments in await spy.run(arguments) },
            runner: WidgetProviderRunner { executable, _, _, _ in
                await script.run(
                    URL(fileURLWithPath: executable).deletingLastPathComponent().lastPathComponent)
            },
            sources: [
                "date": { _, now in
                    WidgetOutput(values: ["date": "\(Int(now.timeIntervalSince1970))"])
                }
            ],
            load: { (bar, snapshot) })
    }

    @Test("everything due goes to SketchyBar in one call")
    func batches() async {
        await script.set("cpu", "42%")
        await script.set("net", ##"{"label": "1 MB/s", "colour": "#ff0000"}"##)
        let host = host([manifest("cpu", every: "2s"), manifest("net", every: "5s")])
        await host.reload(now: start)
        await host.update(now: start)
        let calls = await spy.recorded()
        #expect(calls.count == 1)
        #expect(
            calls.first
                == [
                    "--set", "macarchy.cpu", "label=42%", "label.drawing=on", "drawing=on",
                    "--set", "macarchy.net", "label=1 MB/s", "label.drawing=on",
                    "label.color=0xffff0000", "drawing=on"
                ])
    }

    @Test("a widget is only worked out when due, and unchanged values are not sent again")
    func schedule() async {
        await script.set("cpu", "42%")
        let host = host([manifest("cpu", every: "2s")])
        await host.reload(now: start)
        await host.update(now: start)
        #expect(await host.nextDue() == start.addingTimeInterval(2))
        await host.update(now: start.addingTimeInterval(1))
        #expect(await script.ran() == ["cpu"])
        await host.update(now: start.addingTimeInterval(2))
        #expect(await script.ran() == ["cpu", "cpu"])
        #expect(await spy.recorded().count == 1)
        await script.set("cpu", "43%")
        await host.update(now: start.addingTimeInterval(4))
        #expect(
            await spy.recorded().last == [
                "--set", "macarchy.cpu", "label=43%", "label.drawing=on", "drawing=on"
            ])
    }

    @Test("minute widgets land on the minute")
    func boundary() {
        let now = Date(timeIntervalSince1970: 1_000_000_017)
        #expect(
            WidgetHost.next(after: now, every: "minute")
                == Date(timeIntervalSince1970: 1_000_000_020))
        #expect(
            WidgetHost.next(after: now, every: "second")
                == Date(timeIntervalSince1970: 1_000_000_018))
        #expect(WidgetHost.next(after: now, every: nil) == nil)
    }

    @Test("a failing provider keeps its last label and says why")
    func failure() async {
        let host = host([manifest("cpu", every: "2s")])
        await host.reload(now: start)
        await script.set("cpu", "", status: 1)
        await host.update(now: start)
        #expect(await spy.recorded().last?.contains("label=…") == true)
        #expect(await host.problems["macarchy.cpu"] == "provider.sh broke")
        await script.set("cpu", "42%")
        await host.update(now: start.addingTimeInterval(2))
        await script.set("cpu", "", status: 1)
        await host.update(now: start.addingTimeInterval(4))
        #expect(await spy.recorded().count == 2)
        #expect(await spy.recorded().last?.contains("label=42%") == true)
    }

    @Test("events update only the widgets that asked for them, and waking updates all")
    func events() async {
        let host = host([manifest("battery", events: ["power_source_changed"]), manifest("cpu")])
        await host.reload(now: start)
        await host.trigger("power_source_changed", now: start)
        #expect(await script.ran() == ["battery"])
        await host.trigger("system_woke", now: start)
        #expect(Set(await script.ran()) == ["battery", "cpu"])
    }

    @Test("hidden widgets are left alone")
    func hidden() async {
        let host = host([manifest("cpu", every: "2s")], hidden: ["cpu"])
        await host.reload(now: start)
        await host.update(now: start)
        #expect(await script.ran().isEmpty)
        #expect(await spy.recorded().isEmpty)
        #expect(await host.nextDue() == nil)
    }

    @Test("after SketchyBar refuses a call, everything is sent again")
    func resend() async {
        await script.set("cpu", "42%")
        let host = host([manifest("cpu", every: "2s")])
        await host.reload(now: start)
        await spy.failOnce()
        await host.update(now: start)
        await host.update(now: start.addingTimeInterval(2))
        #expect(await spy.recorded().count == 2)
    }

    @Test("labels come from templates filled with readings and settings")
    func templates() async {
        await script.set("cpu", #"{"values": {"load": "42"}}"#)
        var reading = manifest("clock", label: "It is {date}")
        reading.provider = nil
        reading.source = "date"
        var missing = manifest("battery")
        missing.provider = nil
        missing.source = "battery"
        let host = host([manifest("cpu", label: "{load}{unit}"), reading, missing])
        await host.reload(now: start)
        await host.refresh(now: start)
        let call = await spy.recorded().first ?? []
        #expect(call.contains("label=42%"))
        #expect(call.contains("label=It is 1000000000"))
        #expect(
            await host.problems["macarchy.battery"] == "The battery reading is not available yet")
    }

    @Test("labels are one short line with no control characters")
    func clean() {
        #expect(WidgetHost.clean(" a\nb\u{7}c ") == "a bc")
        #expect(WidgetHost.clean(String(repeating: "x", count: 300)).count == 200)
    }

    @Test("instances take the widget's defaults under their saved settings")
    func instances() {
        var component = BarComponent(
            id: "macarchy.cpu", title: "CPU", side: "right", members: ["macarchy.cpu"])
        component.widget = "cpu"
        component.settings = ["unit": .text("pc"), "gone": .bool(true)]
        var stray = BarComponent(
            id: "macarchy.x", title: "X", side: "right", members: ["macarchy.x"])
        stray.widget = "missing"
        var configuration = BarConfiguration()
        configuration.components = [component, stray]
        let snapshot = WidgetCatalogue.Snapshot(
            entries: [
                .init(
                    id: "cpu", directory: URL(fileURLWithPath: "/w/cpu"), manifest: manifest("cpu"),
                    origin: .user)
            ], problems: [:])
        let resolved = WidgetInstance.resolve(configuration, catalogue: snapshot)
        #expect(resolved.instances.map(\.settings) == [["unit": .text("pc")]])
        #expect(resolved.problems == ["macarchy.x": "There is no widget called missing"])
    }
}
