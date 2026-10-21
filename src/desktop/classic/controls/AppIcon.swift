import AppKit
import SwiftUI

/// The real app icon when it can be found; a neutral placeholder otherwise.
struct AppIcon: View {
    let name: String

    var body: some View {
        if let path = Self.path(for: name) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                .resizable().frame(width: 18, height: 18)
        } else {
            Image(systemName: "app.dashed")
                .foregroundStyle(.secondary).frame(width: 18, height: 18)
        }
    }

    private static func path(for name: String) -> String? {
        for root in [
            "/Applications", "/System/Applications",
            NSHomeDirectory() + "/Applications",
            "/System/Applications/Utilities"
        ] {
            let candidate = "\(root)/\(name).app"
            if FileManager.default.fileExists(atPath: candidate) { return candidate }
        }
        return nil
    }
}
