import SwiftUI

struct ThemeCard: View {
    let theme: InstalledTheme
    let isCurrent: Bool
    let isSelected: Bool
    let isModified: Bool
    /// Applying is the common case, so it is offered on the card itself
    /// rather than only behind the detail dialog.
    var apply: (() -> Void)?
    var isApplying = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                DesktopArtwork(
                    accent: theme.accent, wallpaper: theme.wallpaperURL, palette: theme.palette,
                    height: 168)
                if isCurrent {
                    StatusChip(tone: .good, label: "Current")
                        .padding(Metrics.small)
                } else if hovering, let apply {
                    Button(isApplying ? "Applying…" : "Apply") { apply() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(isApplying)
                        .padding(Metrics.small)
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                }
            }

            HStack(spacing: Metrics.small) {
                Circle()
                    .fill(theme.accent)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().strokeBorder(.white.opacity(0.35)))
                Text(theme.name).font(.cardTitle).lineLimit(1)
                Spacer(minLength: 0)
                if isModified {
                    Text("Edited")
                        .font(.badge)
                        .foregroundStyle(Color.metaText)
                        .padding(.horizontal, Metrics.small)
                        .padding(.vertical, 3)
                        .background(Color.controlWell, in: Capsule())
                }
            }
            .padding(Metrics.medium)
        }
        .background(Color.cardSurface)
        .clipShape(shape)
        .overlay(
            shape.strokeBorder(
                isSelected ? Color.accentColor : Color.cardBorder,
                lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(Rectangle())
        .animation(reduceMotion ? nil : Motion.hover, value: hovering)
        .onHover { hovering = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(theme.name)\(isCurrent ? ", current theme" : "")\(isModified ? ", edited" : "")")
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.radiusCard, style: .continuous)
    }
}
