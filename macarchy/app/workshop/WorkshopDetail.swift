import SwiftUI

/// What a listing actually looks like, led by the terminal.
///
/// A theme colours the terminal as much as the desktop, and the palette is
/// what people compare between themes — so the listing opens on a real
/// rendered shell rather than a stock photo of a desktop.
struct WorkshopDetail: View {
    @Environment(AppModel.self) private var model
    let item: WorkshopItem
    let close: () -> Void

    private var theme: InstalledTheme? { item.previewTheme(in: model.themes.themes) }
    private var palette: GhosttyPalette? { theme?.palette }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: Metrics.cardGap) {
                    desktopStage
                    labelled("Terminal") { terminalStage }
                    labelled("Palette") { paletteStage }
                    details
                }
                .padding(Metrics.xl)
                .frame(width: 620)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .background(WorkshopScrollLimiter())
        }
        .frame(width: 620, height: 660)
        .background(Color.paneBackground)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: Metrics.medium) {
            RoundedRectangle(cornerRadius: Metrics.radiusControl, style: .continuous)
                .fill(item.accent)
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white))

            VStack(alignment: .leading, spacing: 1) {
                Text(item.name).font(.sectionTitle)
                Text(item.subtitle).font(.meta).foregroundStyle(.secondary).lineLimit(1)
            }

            Spacer(minLength: Metrics.medium)

            Text(item.price)
                .font(.cardTitle)
                .padding(.horizontal, Metrics.medium)
                .padding(.vertical, Metrics.xs)
                .background(item.accent.opacity(0.16), in: Capsule())
                .overlay(Capsule().strokeBorder(item.accent.opacity(0.35), lineWidth: 1))

            CloseButton(action: close)
        }
        .padding(Metrics.xl)
    }

    // MARK: - Preview

    private func labelled(
        _ title: String, @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: Metrics.small) {
            Text(title).font(.cardTitle).foregroundStyle(.secondary)
                .padding(.horizontal, Metrics.xs)
            content()
        }
    }

    @ViewBuilder
    private var terminalStage: some View {
        if let palette {
            TerminalWindow(
                title: "\(item.name.lowercased()) — zsh",
                accent: item.accent,
                background: palette.background
            ) {
                TerminalPreview(palette: palette, themeName: "macarchy-settings")
            }
        } else {
            ContentUnavailableView(
                "No terminal palette", systemImage: "terminal",
                description: Text("This listing has no ghostty.conf to render from.")
            )
            .frame(height: 260)
        }
    }

    private var desktopStage: some View {
        DesktopArtwork(
            accent: item.accent,
            wallpaper: theme?.wallpaperURL,
            palette: palette,
            variant: item.category == "Menu Bars" ? .menuBar : .desktop,
            height: 300
        )
        .clipShape(RoundedRectangle(cornerRadius: Metrics.radiusCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.radiusCard, style: .continuous)
                .strokeBorder(Color.cardBorder, lineWidth: 1)
        )
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var paletteStage: some View {
        if let palette {
            VStack(spacing: Metrics.medium) {
                swatchRow("Normal", range: 0..<8, palette: palette)
                swatchRow("Bright", range: 8..<16, palette: palette)
                HStack(spacing: Metrics.medium) {
                    named("Background", palette.background)
                    named("Foreground", palette.foreground)
                    named("Cursor", palette.cursor)
                    named("Accent", item.accent)
                }
            }
            .padding(Metrics.large)
            .background(Color.cardSurface, in: card)
            .overlay(card.strokeBorder(Color.cardBorder, lineWidth: 1))
        } else {
            ContentUnavailableView(
                "No palette", systemImage: "paintpalette",
                description: Text("This listing has no colours to show.")
            )
            .frame(height: 260)
        }
    }

    private func swatchRow(
        _ label: String, range: Range<Int>, palette: GhosttyPalette
    ) -> some View {
        VStack(alignment: .leading, spacing: Metrics.small) {
            Text(label.uppercased()).eyebrowStyle()
            HStack(spacing: Metrics.xs) {
                ForEach(range, id: \.self) { index in
                    RoundedRectangle(cornerRadius: Metrics.radiusSmall, style: .continuous)
                        .fill(palette.ansi(index))
                        .frame(height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: Metrics.radiusSmall, style: .continuous)
                                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                        )
                        .hoverHelp("ANSI \(index)")
                }
            }
        }
    }

    private func named(_ label: String, _ colour: Color) -> some View {
        VStack(spacing: Metrics.xs) {
            RoundedRectangle(cornerRadius: Metrics.radiusSmall, style: .continuous)
                .fill(colour)
                .frame(height: 30)
                .overlay(
                    RoundedRectangle(cornerRadius: Metrics.radiusSmall, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1))
            Text(label).font(.badge).foregroundStyle(Color.metaText)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Details

    private var details: some View {
        VStack(alignment: .leading, spacing: Metrics.medium) {
            HStack(spacing: Metrics.small) {
                StatusChip(tone: .idle, label: item.category)
                StatusChip(tone: .idle, label: "Macarchy Studio")
                StatusChip(tone: .warning, label: "Concept preview")
                HelpTooltip(
                    text:
                        "Illustrative preview and price. Downloads and purchases are not available yet."
                )
            }

            Text(
                item.category == "Menu Bars"
                    ? "A coordinated menu bar layout with matching colours and component styling."
                    : "A coordinated palette, wallpaper direction and window styling for a "
                        + "cohesive desktop."
            )
            .font(.system(size: 13)).foregroundStyle(.secondary)
        }
    }

    private var card: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.radiusCard, style: .continuous)
    }
}
