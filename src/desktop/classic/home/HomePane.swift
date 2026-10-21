import AppKit
import Macarchy
import SwiftUI

struct HomePane: View {
    @Environment(AppModel.self) private var model

    private var current: InstalledTheme? {
        model.themes.themes.first { $0.name == model.themes.current }
    }

    private var lastChanged: String {
        guard let latest = model.snapshots.snapshots.map(\.created).max() else { return "Never" }
        return latest.formatted(.relative(presentation: .numeric, unitsStyle: .narrow))
    }

    private var runningCount: Int { model.daemons.runningCount }

    var body: some View {
        SettingsPage("Home", subtitle: DesignSettings.shared.values.homeTitle) {
            hero
            SectionHeading("Make it feel right")
            quickActions
            SettingsCard("Explore") {
                SettingRow("Workshop", help: "Explore themes and menu bar designs.") {
                    Button("Open Workshop") { model.selection = .workshop }
                }
            }
        }
        .task {
            await model.daemons.refresh()
            model.snapshots.refresh()
        }
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            DesktopArtwork(
                accent: current?.accent ?? .accentColor,
                wallpaper: current?.wallpaperURL,
                palette: current?.palette,
                height: 210)
            LinearGradient(
                colors: [.clear, .black.opacity(0.5), .black.opacity(0.88)],
                startPoint: .center, endPoint: .bottom)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: Metrics.small) {
                    Text("YOUR DESKTOP").font(.eyebrow).tracking(1.2)
                        .foregroundStyle(.white.opacity(0.75))
                    Text(current?.name ?? "Make room for your next idea.")
                        .font(.pageTitle).foregroundStyle(.white)
                    HStack(spacing: Metrics.small) {
                        StatusChip(
                            tone: runningCount == Daemon.allCases.count ? .good : .warning,
                            label: "\(runningCount)/\(Daemon.allCases.count) services",
                            live: runningCount == Daemon.allCases.count)
                        StatusChip(
                            tone: .idle, label: "\(model.themes.themes.count) themes")
                    }
                }
                Spacer(minLength: Metrics.large)
                Button("Browse themes") { model.selection = .themes }
            }
            .padding(Metrics.xl)
        }
        .frame(height: 210)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.radiusCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.radiusCard, style: .continuous)
                .strokeBorder(Color.cardBorder, lineWidth: 1)
        )
        .appearStagger(0)
    }

    // MARK: - Stats

    private var stats: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 158), spacing: Metrics.medium)],
            spacing: Metrics.medium
        ) {
            StatTile(
                symbol: "paintpalette", value: "\(model.themes.themes.count)",
                caption: "Themes", tint: .purple, emphasis: true
            )
            .appearStagger(1)

            StatTile(
                symbol: "command", value: "\(model.shortcuts.bindings.count)",
                caption: "Shortcuts", tint: .blue, emphasis: true
            )
            .appearStagger(2)

            StatTile(
                symbol: "rectangle.3.group",
                value: layoutName, caption: "Layout", tint: .teal
            )
            .appearStagger(3)

            StatTile(
                symbol: "clock.arrow.circlepath", value: lastChanged,
                caption: "Last change", tint: .orange
            )
            .appearStagger(4)
        }
        .onAppear { if model.shortcuts.bindings.isEmpty { model.shortcuts.reload() } }
    }

    private var layoutName: String {
        switch model.layout.layout {
        case "bsp": "Tiled"
        case "stack": "Stacked"
        default: "Freeform"
        }
    }

    // MARK: - Quick actions

    private var quickActions: some View {
        QuickActionGrid {
            shortcut(.themes, detail: "Wallpaper, colours and the whole look", tint: .purple, at: 0)
            shortcut(.menuBar, detail: "Your essentials, arranged your way", tint: .blue, at: 1)
            shortcut(.borders, detail: "A little definition for your windows", tint: .teal, at: 2)
            shortcut(.layout, detail: "Give every window a place", tint: .orange, at: 3)
            shortcut(.shortcuts, detail: "Less reaching, more doing", tint: .pink, at: 4)
            shortcut(.plugins, detail: "Choose the tools that belong here", tint: .green, at: 5)
        }
    }

    private func shortcut(_ pane: Pane, detail: String, tint: Color, at index: Int) -> some View {
        Button {
            withAnimation(Motion.snappy) { model.selection = pane }
        } label: {
            QuickAction(pane: pane, detail: detail, tint: tint)
        }
        .buttonStyle(.plain)
        .hoverLift(scale: 1.015, lift: 1)
        .appearStagger(index)
        .accessibilityLabel("\(pane.title). \(detail)")
    }

}

/// Six cards need stable measurements, rather than lazy height estimates
/// that can change when an earlier row scrolls back into view.
private struct QuickActionGrid: Layout {
    private struct Measurements {
        let columns: Int
        let width: CGFloat
        let height: CGFloat
    }

    private let minimumWidth: CGFloat = 220
    private let spacing = Metrics.gridGap

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let grid = measurements(width: proposal.width ?? minimumWidth, subviews: subviews)
        let rows = (subviews.count + grid.columns - 1) / grid.columns
        return CGSize(
            width: proposal.width ?? minimumWidth,
            height: CGFloat(rows) * grid.height + CGFloat(max(0, rows - 1)) * spacing)
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        let grid = measurements(width: bounds.width, subviews: subviews)
        for (index, view) in subviews.enumerated() {
            view.place(
                at: CGPoint(
                    x: bounds.minX + CGFloat(index % grid.columns) * (grid.width + spacing),
                    y: bounds.minY + CGFloat(index / grid.columns) * (grid.height + spacing)),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: grid.width, height: grid.height))
        }
    }

    private func measurements(width proposedWidth: CGFloat, subviews: Subviews) -> Measurements {
        let width =
            proposedWidth.isFinite
            ? max(0, proposedWidth) : minimumWidth * CGFloat(max(1, subviews.count))
        let columns = max(1, min(subviews.count, Int((width + spacing) / (minimumWidth + spacing))))
        let cardWidth = max(0, (width - CGFloat(columns - 1) * spacing) / CGFloat(columns))
        let height =
            subviews.map {
                $0.sizeThatFits(ProposedViewSize(width: cardWidth, height: nil)).height
            }.max() ?? 0
        return Measurements(columns: columns, width: cardWidth, height: height)
    }
}

private struct QuickAction: View {
    let pane: Pane
    let detail: String
    let tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.medium) {
            Image(systemName: pane.symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(
                    tint.opacity(hovering ? 0.22 : 0.14),
                    in: RoundedRectangle(cornerRadius: Metrics.radiusControl, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(pane.title).font(.cardTitle)
                Text(detail)
                    .font(.rowDetail).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "arrow.up.right")
                .font(.system(size: 11))
                .foregroundStyle(hovering ? tint : .secondary)
                .offset(
                    x: hovering && !reduceMotion ? 2 : 0,
                    y: hovering && !reduceMotion ? -2 : 0)
        }
        .padding(Metrics.large)
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
        .background(Color.cardSurface, in: shape)
        .overlay(
            shape.strokeBorder(hovering ? tint.opacity(0.45) : Color.cardBorder, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .animation(reduceMotion ? nil : Motion.hover, value: hovering)
        .onHover { hovering = $0 }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.radiusCard, style: .continuous)
    }
}
