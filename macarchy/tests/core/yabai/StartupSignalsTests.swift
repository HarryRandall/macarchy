import Testing

@testable import Macarchy

struct StartupSignalsTests {
    @Test("startup registers every focus and Space signal under a Macarchy label")
    func signalsAreRegistered() {
        let labels = Startup.signals.compactMap { arguments in
            arguments.first { $0.hasPrefix("label=") }.map { String($0.dropFirst(6)) }
        }
        #expect(
            Set(labels) == [
                "macarchy_mission_control_exit", "macarchy_refocus_space",
                "macarchy_window_created", "macarchy_window_deminimized",
                "macarchy_refocus_destroyed", "macarchy_refocus_terminated"
            ])
        let missionControl = Startup.signals.first { $0.contains("event=mission_control_exit") }
        #expect(missionControl?.last?.contains("--focus \"$id\"") == true)
        #expect(missionControl?.last?.contains("macarchy_spaces_changed") == true)
    }
}
