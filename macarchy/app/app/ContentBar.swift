import SwiftUI
import Macarchy

/// The strip along the top of the pane. The sidebar toggle and the history
/// arrows sit beside the window buttons, search is centred, and status
/// controls stay at the trailing edge.
struct ContentBar: View {
    static let height: CGFloat = 44

    var body: some View {
        ZStack {
            ToolbarSearch()
                .frame(maxWidth: 320)
                .padding(.horizontal, 120)
                .frame(maxWidth: .infinity)
            HStack(spacing: 2) {
                Spacer(minLength: Metrics.medium)
                DaemonStatusPill()
                ConsoleToggle()
            }
            .padding(.trailing, Metrics.medium)
        }
        .frame(height: Self.height)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }
}

/// Opens the existing palette from the centre of the window's toolbar.
struct ToolbarSearch: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Button {
            model.modal.present(inContent: true) { CommandPalette() }
        } label: {
            HStack(spacing: Metrics.small) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                Text("Search").font(.rowTitle)
                Spacer(minLength: Metrics.small)
                Text("⌘K").font(.meta)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, Metrics.medium)
            .frame(height: 28)
            .background(Color.controlWell, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.cardBorder, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(InteractiveButtonStyle(cornerRadius: 14))
        .focusEffectDisabled()
        .accessibilityLabel("Search")
        .hoverHelp("Search themes, settings and actions")
    }
}
/// How the services are doing, in the corner where a status light belongs.
/// It was at the foot of the sidebar, which is the first thing the sidebar
/// gives up when it collapses.
private struct DaemonStatusPill: View {
    @Environment(AppModel.self) private var model

    private var allRunning: Bool { model.daemons.runningCount == Daemon.allCases.count }
    private var summary: String {
        "\(model.daemons.runningCount) of \(Daemon.allCases.count) services running"
    }

    var body: some View {
        Button {
            withAnimation(Motion.snappy) { model.selection = .advanced }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(allRunning ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)
                Text("\(model.daemons.runningCount)/\(Daemon.allCases.count)")
                    .font(.meta)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, Metrics.small)
            .frame(height: 24)
            .background(Color.controlWell, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .hoverHelp(summary)
        .accessibilityLabel(summary)
        .motion(Motion.snappy, value: model.daemons.runningCount)
    }
}

/// Opens the command log beside the pane. The glyph carries how the last
/// command went, so the bar still says something when the panel is shut.
private struct ConsoleToggle: View {
    @Environment(AppModel.self) private var model

    private var failed: Bool { model.log.latest.map { !$0.ok } ?? false }

    private var help: String {
        guard let latest = model.log.latest else { return "Show the console" }
        return "\(latest.ok ? "Ran" : "Failed"): \(latest.command)"
    }

    /// Open, the glyph carries the accent. Closed, it is left alone so the
    /// button style can brighten it under the pointer.
    @ViewBuilder
    private var glyph: some View {
        let image = Image(systemName: "terminal").font(.system(size: 14, weight: .medium))
        if model.consoleOpen {
            image.foregroundStyle(model.interfaceAccent)
        } else {
            image
        }
    }

    var body: some View {
        Button {
            withAnimation(Motion.snappy) { model.consoleOpen.toggle() }
        } label: {
            glyph
                .overlay(alignment: .topTrailing) {
                    if failed {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                            .offset(x: 3, y: -2)
                    }
                }
                .frame(width: 28, height: 26)
                .contentShape(RoundedRectangle(cornerRadius: Metrics.radiusSmall))
        }
        .buttonStyle(BarButtonStyle())
        .focusEffectDisabled()
        .hoverHelp(help)
        .accessibilityLabel(model.consoleOpen ? "Hide the console" : "Show the console")
    }
}
