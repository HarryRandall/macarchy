import Foundation
import Testing

@testable import Macarchy

@Suite("Command components")
struct BarCommandItemTests {
    private func command(_ text: String?, every interval: Int?) -> BarComponent {
        var component = BarComponent(
            id: "macarchy.up", title: "Uptime", side: "right", members: ["macarchy.up"])
        component.kind = "command"
        component.command = text
        component.interval = interval
        return component
    }

    @Test("a command item runs its command on a schedule and shows the output")
    func script() throws {
        var configuration = BarConfiguration()
        configuration.components = [command("uptime | cut -d, -f1", every: 60)]
        try configuration.validate()
        let settings = BarCommands.settings(configuration, startup: true)
        let script = try #require(settings.first { $0.hasPrefix("script=") })
        #expect(script.hasSuffix(#"--set "$NAME" label="$(uptime | cut -d, -f1)""#))
        #expect(settings.contains("update_freq=60"))
        #expect(settings.contains("updates=on"))
        #expect(settings.contains("label.drawing=on"))
    }

    @Test("a command item needs a command and a sensible interval")
    func validation() {
        let broken = [command(nil, every: 5), command("  ", every: 5), command("date", every: 0)]
        for component in broken {
            var configuration = BarConfiguration()
            configuration.components = [component]
            #expect(throws: ConfigurationError.self) { try configuration.validate() }
        }
    }

    @Test("a bar saved before command items still decodes")
    func decodesOldBar() throws {
        let json = #"{"id":"x","title":"X","side":"left","members":["x"]}"#
        let component = try JSONDecoder().decode(BarComponent.self, from: Data(json.utf8))
        #expect(component.command == nil && component.interval == nil)
    }
}
