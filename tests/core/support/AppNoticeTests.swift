import Foundation
import Testing

@testable import Macarchy

/// Inputs are passed in: the web view suites change `MACARCHY_HOME` for the
/// whole test process.
@Suite("App notices")
struct AppNoticeTests {
    @Test("a copy takes notices from its own home only")
    func ownHome() {
        #expect(AppNotice.accepts("/Users/a", home: "/Users/a", isolated: false))
        #expect(!AppNotice.accepts("/tmp/demo", home: "/Users/a", isolated: false))
        #expect(AppNotice.accepts("/tmp/demo", home: "/tmp/demo", isolated: true))
        #expect(!AppNotice.accepts("/Users/a", home: "/tmp/demo", isolated: true))
    }

    @Test("a notice from an older CLI reaches only the installed copy")
    func olderCLI() {
        #expect(AppNotice.accepts(nil, home: "/Users/a", isolated: false))
        #expect(!AppNotice.accepts(nil, home: "/tmp/demo", isolated: true))
    }

    @Test("an isolated copy's widgets click through its own CLI and home")
    func isolatedClicks() {
        let executable = URL(fileURLWithPath: "/tmp/Dev Build.app/Contents/MacOS/MacarchySettings")
        let command = WidgetLook.isolatedCommand(
            environment: ["MACARCHY_HOME": "/tmp/demo", "MACARCHY_SEARCH_PATH": "/tmp/demo/bin"],
            isolated: true, executable: executable)
        #expect(
            command
                == "MACARCHY_HOME='/tmp/demo' MACARCHY_SEARCH_PATH='/tmp/demo/bin' "
                + "'/tmp/Dev Build.app/Contents/MacOS/macarchy'")
        #expect(
            WidgetLook.isolatedCommand(environment: [:], isolated: false, executable: executable)
                == nil)
    }
}
