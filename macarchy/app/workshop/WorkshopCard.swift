import SwiftUI

/// A listing in the grid.
///
/// The card carries no hover help: it already shows its name, its category
/// and its price, and a bubble describing it floated over the heading above.
/// Hover reveals the action instead of describing the card.
struct WorkshopCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let item: WorkshopItem

    @State private var hovering = false

    private var theme: InstalledTheme? { item.previewTheme(in: model.themes.themes) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            artwork
            footer
        }
        .background(Color.cardSurface)
        .clipShape(shape)
        .overlay(
            shape.strokeBorder(
                hovering ? item.accent.opacity(0.65) : Color.cardBorder, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .animation(reduceMotion ? nil : Motion.hover, value: hovering)
        .onHover { hovering = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.name). \(item.subtitle). \(item.category). \(item.price)")
    }

    private var artwork: some View {
        ZStack {
            DesktopArtwork(
                accent: item.accent,
                wallpaper: theme?.wallpaperURL,
                palette: theme?.palette,
                variant: item.category == "Menu Bars" ? .menuBar : .compact,
                height: 132)

            // The call to action lives here rather than in a tooltip.
            if hovering {
                ZStack {
                    Color.black.opacity(0.35)
                    HStack(spacing: Metrics.xs) {
                        Image(systemName: "eye")
                        Text("View")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Metrics.medium)
                    .padding(.vertical, Metrics.small - 1)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                }
                .transition(.opacity)
                .allowsHitTesting(false)
            }
        }
        .frame(height: 132)
        .clipped()
    }

    /// The price sits in the footer beside the name.
    ///
    /// Floated over the artwork it landed on the preview's own menu bar clock,
    /// which read as a rendering fault rather than a badge.
    private var footer: some View {
        VStack(alignment: .leading, spacing: Metrics.xs + 1) {
            HStack(alignment: .firstTextBaseline, spacing: Metrics.small) {
                Text(item.name).font(.cardTitle).lineLimit(1)
                Spacer(minLength: Metrics.xs)
                Text(item.price)
                    .font(.badge)
                    .monospacedDigit()
                    .padding(.horizontal, Metrics.small)
                    .padding(.vertical, 2)
                    .background(item.accent.opacity(0.16), in: Capsule())
                    .overlay(Capsule().strokeBorder(item.accent.opacity(0.35), lineWidth: 1))
            }
            Text(item.subtitle)
                .font(.rowDetail).foregroundStyle(.secondary).lineLimit(1)
            HStack(spacing: Metrics.xs + 2) {
                Circle().fill(item.accent).frame(width: 6, height: 6)
                Text(item.category).font(.badge).foregroundStyle(Color.metaText)
                Spacer(minLength: 0)
                if let palette = theme?.palette {
                    HStack(spacing: 2) {
                        ForEach(1..<7, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                                .fill(palette.ansi(index))
                                .frame(width: 9, height: 9)
                        }
                    }
                }
            }
        }
        .padding(Metrics.medium)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.radiusCard, style: .continuous)
    }
}

/// The compact form of a listing, for the list density.
struct WorkshopRow: View {
    @Environment(AppModel.self) private var model
    let item: WorkshopItem

    private var theme: InstalledTheme? { item.previewTheme(in: model.themes.themes) }

    var body: some View {
        HStack(spacing: Metrics.medium) {
            DesktopArtwork(
                accent: item.accent,
                wallpaper: theme?.wallpaperURL,
                palette: theme?.palette,
                variant: item.category == "Menu Bars" ? .menuBar : .compact,
                height: 46
            )
            .frame(width: 80)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.radiusSmall, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(item.name).font(.cardTitle)
                Text(item.subtitle).font(.rowDetail).foregroundStyle(.secondary).lineLimit(1)
            }

            Spacer(minLength: Metrics.small)

            Text(item.category).font(.badge).foregroundStyle(Color.metaText)
            Text(item.price)
                .font(.badge)
                .padding(.horizontal, Metrics.small)
                .padding(.vertical, 2)
                .background(item.accent.opacity(0.16), in: Capsule())
            Image(systemName: "chevron.right")
                .font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, Metrics.medium)
        .padding(.vertical, Metrics.small)
        .background(Color.cardSurface, in: shape)
        .overlay(shape.strokeBorder(Color.cardBorder, lineWidth: 1))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.name). \(item.subtitle). \(item.category). \(item.price)")
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.radiusCard, style: .continuous)
    }
}
