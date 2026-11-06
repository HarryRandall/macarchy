import AppKit
import Foundation
import Macarchy

/// Where the windows keep their own state, such as the selected pane and the
/// sidebar. A development run shares the installed copy's bundle identifier,
/// so with its own home it writes to a separate suite instead of the
/// installed app's preferences.
enum Preferences {
    static let developmentSuite = "io.github.harryrandall.macarchy.development"

    static var isolated: Bool { Paths.isolated }

    /// Read on every use rather than once, because the web view tests set
    /// `MACARCHY_HOME` after launch.
    static var store: UserDefaults {
        guard isolated else { return .standard }
        guard let suite = UserDefaults(suiteName: developmentSuite) else {
            preconditionFailure("The development preferences suite could not be opened.")
        }
        return suite
    }

    /// Frame autosave always writes to the standard domain, so an isolated
    /// window does not restore or save a frame and opens centred instead.
    /// Window restoration writes the installed app's saved state too, so it
    /// is off for isolated windows as well.
    @MainActor
    static func restoreFrame(of window: NSWindow, autosaveName: NSWindow.FrameAutosaveName) {
        guard !isolated else {
            window.isRestorable = false
            window.center()
            return
        }
        if !window.setFrameUsingName(autosaveName) { window.center() }
        window.setFrameAutosaveName(autosaveName)
    }
}
