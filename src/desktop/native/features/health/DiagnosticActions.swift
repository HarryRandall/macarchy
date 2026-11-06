import AppKit
import Foundation
import Macarchy

/// Native side effects are replaceable by recorders in off-screen tests.
@MainActor
struct DiagnosticActions {
    var copy: (String) -> Bool
    var open: (URL) -> Bool
    var reveal: () -> Void

    static var live: Self {
        Self(
            copy: {
                NSPasteboard.general.clearContents()
                return NSPasteboard.general.setString($0, forType: .string)
            },
            open: { NSWorkspace.shared.open($0) },
            reveal: { NSWorkspace.shared.activateFileViewerSelecting([Paths.appRoot]) })
    }
}
