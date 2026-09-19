import SwiftUI

/// A terminal rendered in the theme's own ghostty palette.
///
/// Themes colour the terminal as much as the desktop, and that half was
/// previously invisible in the UI. The listing is fixed rather than randomised
/// — a preview that churns on every redraw is harder to compare between themes,
/// which is the whole point of showing it.
struct TerminalPreview: View {
    let palette: GhosttyPalette
    let themeName: String

    private struct Entry {
        let mode: String
        let size: String
        let date: String
        let name: String
        let kind: Kind
        enum Kind { case directory, executable, symlink, archive, plain }
    }

    private var entries: [Entry] {
        [
            .init(mode: "drwxr-xr-x", size: "  160", date: "19 Sep 18:31", name: "src", kind: .directory),
            .init(mode: "drwxr-xr-x", size: "  128", date: "19 Sep 17:50", name: "Tests", kind: .directory),
            .init(mode: "-rwxr-xr-x", size: " 92K", date: "19 Sep 18:12", name: "borders", kind: .executable),
            .init(mode: "-rw-r--r--", size: "2.1K", date: "19 Sep 18:12", name: "README.md", kind: .plain),
            .init(mode: "-rw-r--r--", size: " 545", date: "14 May 22:23", name: "makefile", kind: .plain),
            .init(mode: "lrwxr-xr-x", size: "  45", date: "19 Sep 18:31", name: "themes -> ../themes", kind: .symlink),
            .init(mode: "-rw-r--r--", size: " 34K", date: "19 Sep 16:04", name: "assets.tar.gz", kind: .archive)
        ]
    }

    private func color(for kind: Entry.Kind) -> Color {
        switch kind {
        case .directory: palette.blue
        case .executable: palette.green
        case .symlink: palette.cyan
        case .archive: palette.red
        case .plain: palette.foreground
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 0) {
                Text("harry").foregroundStyle(palette.green)
                Text(" ~/").foregroundStyle(palette.blue)
                Text(themeName).foregroundStyle(palette.magenta)
                Text(" ❯ ").foregroundStyle(palette.cyan)
                Text("ls -la").foregroundStyle(palette.foreground)
            }

            Text("total 248").foregroundStyle(palette.brightBlack)

            ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                HStack(spacing: 0) {
                    Text(entry.mode).foregroundStyle(palette.brightBlack)
                    Text("  1 harry  staff ").foregroundStyle(palette.brightBlack)
                    Text(entry.size).foregroundStyle(palette.yellow)
                    Text(" \(entry.date) ").foregroundStyle(palette.brightBlack)
                    Text(entry.name).foregroundStyle(color(for: entry.kind))
                }
            }

            HStack(spacing: 0) {
                Text("harry").foregroundStyle(palette.green)
                Text(" ~/").foregroundStyle(palette.blue)
                Text(themeName).foregroundStyle(palette.magenta)
                Text(" ❯ ").foregroundStyle(palette.cyan)
                Rectangle().fill(palette.cursor).frame(width: 7, height: 13)
            }
        }
        .font(.system(size: 11, design: .monospaced))
        .lineSpacing(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(palette.background)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator))
        .accessibilityLabel("Terminal preview for \(themeName)")
    }
}
