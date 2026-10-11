import SwiftUI

/// A terminal rendered in the theme's own ghostty palette.
///
/// Themes colour the terminal as much as the desktop, and that half is the
/// part people actually compare. The listing is fixed rather than randomised —
/// a preview that churns on every redraw cannot be compared between themes,
/// which is the whole point of showing it.
struct TerminalPreview: View {
    let palette: GhosttyPalette
    let themeName: String
    /// Drops the lower rows when the preview has to fit inside a card.
    var compact = false

    private struct Entry {
        let mode: String
        let size: String
        let date: String
        let name: String
        let kind: Kind

        enum Kind {
            case directory, executable, symlink, archive, markdown, config, plain

            var symbol: String {
                switch self {
                case .directory: "folder.fill"
                case .executable: "gearshape.fill"
                case .symlink: "arrow.turn.up.right"
                case .archive: "shippingbox.fill"
                case .markdown: "doc.richtext.fill"
                case .config: "slider.horizontal.3"
                case .plain: "doc.fill"
                }
            }
        }
    }

    private static let entries: [Entry] = [
        .init(
            mode: "drwxr-xr-x", size: "   -", date: "20 Sep 00:24", name: ".build",
            kind: .directory),
        .init(
            mode: ".rw-r--r--", size: " 247", date: "19 Sep 22:26", name: ".editorconfig",
            kind: .config),
        .init(
            mode: "drwxr-xr-x", size: "   -", date: "20 Sep 00:09", name: ".git",
            kind: .directory),
        .init(
            mode: ".rw-r--r--", size: "1.1k", date: "19 Sep 20:05", name: ".swift-format",
            kind: .config),
        .init(
            mode: ".rw-r--r--", size: "2.5k", date: "19 Sep 22:26", name: "CONTRIBUTING.md",
            kind: .markdown),
        .init(
            mode: "drwxr-xr-x", size: "   -", date: "19 Sep 22:32", name: "design",
            kind: .directory),
        .init(
            mode: "drwxr-xr-x", size: "   -", date: "19 Sep 22:26", name: "macarchy",
            kind: .directory),
        .init(
            mode: ".rwxr-xr-x", size: " 92k", date: "20 Sep 00:24", name: "borders",
            kind: .executable),
        .init(
            mode: ".rw-r--r--", size: "2.0k", date: "19 Sep 22:51", name: "README.md",
            kind: .markdown),
        .init(
            mode: "lrwxr-xr-x", size: "  45", date: "19 Sep 22:26", name: "themes ⇒ ../themes",
            kind: .symlink)
    ]

    private var visible: [Entry] {
        compact ? Array(Self.entries.prefix(5)) : Self.entries
    }

    private func colour(for kind: Entry.Kind) -> Color {
        switch kind {
        case .directory: palette.blue
        case .executable: palette.green
        case .symlink: palette.cyan
        case .archive: palette.red
        case .markdown: palette.yellow
        case .config: palette.magenta
        case .plain: palette.foreground
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            prompt(command: "ls -la")

            ForEach(Array(visible.enumerated()), id: \.offset) { _, entry in
                row(entry)
            }

            prompt(command: nil)
        }
        .font(.system(size: compact ? 10 : 11, design: .monospaced))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, compact ? 12 : 16)
        .padding(.vertical, compact ? 10 : 14)
        .background(palette.background)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Terminal preview for \(themeName)")
    }

    private func prompt(command: String?) -> some View {
        HStack(spacing: 0) {
            Text(themeName).foregroundStyle(palette.yellow).fontWeight(.bold)
            Text(" ❯ ").foregroundStyle(palette.magenta).fontWeight(.bold)
            if let command {
                Text(command).foregroundStyle(palette.foreground)
            } else {
                Rectangle()
                    .fill(palette.cursor)
                    .frame(width: compact ? 6 : 7, height: compact ? 12 : 14)
            }
        }
    }

    private func row(_ entry: Entry) -> some View {
        HStack(spacing: 0) {
            permissions(entry.mode)
            Text("  \(entry.size) ")
                .foregroundStyle(entry.size.contains("-") ? palette.brightBlack : palette.green)
            Text("harry ").foregroundStyle(palette.yellow)
            Text("\(entry.date) ").foregroundStyle(palette.brightBlack)
            Image(systemName: entry.kind.symbol)
                .font(.system(size: compact ? 8 : 9))
                .foregroundStyle(colour(for: entry.kind))
                .frame(width: compact ? 13 : 15, alignment: .leading)
            Text(entry.name)
                .foregroundStyle(colour(for: entry.kind))
                .fontWeight(entry.kind == .directory ? .bold : .regular)
                .underline(entry.kind == .markdown)
            Spacer(minLength: 0)
        }
        .lineLimit(1)
    }

    /// Permission bits coloured per character, the way a modern `ls`
    /// replacement does: read yellow, write red, execute green.
    private func permissions(_ mode: String) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(mode.enumerated()), id: \.offset) { _, character in
                Text(String(character))
                    .foregroundStyle(permissionColour(character))
            }
        }
    }

    private func permissionColour(_ character: Character) -> Color {
        switch character {
        case "d": palette.blue
        case "l": palette.cyan
        case "r": palette.yellow
        case "w": palette.red
        case "x": palette.green
        default: palette.brightBlack
        }
    }
}

/// Window chrome around a terminal, so a preview reads as an application
/// rather than a coloured rectangle.
struct TerminalWindow<Content: View>: View {
    var title: String?
    var accent: Color = .accentColor
    var background: Color = .black
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Metrics.small) {
                HStack(spacing: 6) {
                    Circle().fill(Color(red: 1, green: 0.37, blue: 0.34))
                    Circle().fill(Color(red: 1, green: 0.74, blue: 0.18))
                    Circle().fill(Color(red: 0.16, green: 0.79, blue: 0.25))
                }
                .frame(height: 9)
                .fixedSize(horizontal: false, vertical: true)

                if let title {
                    Spacer(minLength: Metrics.small)
                    Text(title)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                }
                Spacer(minLength: Metrics.small)
                Image(systemName: "ellipsis")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(.horizontal, Metrics.medium)
            .padding(.vertical, Metrics.small)
            .background(.black.opacity(0.35))

            content
        }
        .background(background)
        .clipShape(shape)
        .overlay(shape.strokeBorder(accent.opacity(0.55), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.radiusCard, style: .continuous)
    }
}
