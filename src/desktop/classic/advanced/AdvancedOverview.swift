import Macarchy
import SwiftUI

/// The state of the desktop in one band of tiles.
///
/// This replaced a progress ring and a seven-day bar chart that between them
/// filled a whole screen band to report two numbers — and rendered one bar
/// beside six empty columns on any day you had not changed a setting.
struct AdvancedOverview: View {
    @Environment(AppModel.self) private var model

    private var segments: [HealthStrip.Segment] {
        Daemon.allCases.map {
            .init(
                id: $0.rawValue, label: Self.serviceName($0),
                ok: model.daemons.states[$0]?.isRunning == true)
        }
    }

    /// Backups per day for the last fortnight, oldest first.
    private var backupTrend: [Double] {
        let calendar = Calendar.current
        return (-13...0).map { offset in
            guard
                let day = calendar.date(
                    byAdding: .day, value: offset, to: calendar.startOfDay(for: .now))
            else { return 0 }
            return Double(
                model.snapshots.snapshots.filter { calendar.isDate($0.created, inSameDayAs: day) }
                    .count)
        }
    }

    private var lastBackup: String {
        guard let latest = model.snapshots.snapshots.map(\.created).max() else { return "None" }
        return latest.formatted(.relative(presentation: .numeric, unitsStyle: .narrow))
    }

    private var runningCount: Int { model.daemons.runningCount }
    private var allRunning: Bool { runningCount == Daemon.allCases.count }

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 168), spacing: Metrics.medium)],
            spacing: Metrics.medium
        ) {
            StatTile(
                symbol: allRunning ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                value: "\(runningCount)/\(Daemon.allCases.count)",
                caption: "Services",
                tint: allRunning ? .green : .orange,
                emphasis: true
            ) {
                HealthStrip(segments: segments).padding(.top, 2)
            }
            .appearStagger(0)

            StatTile(
                symbol: "clock.arrow.circlepath",
                value: "\(model.snapshots.snapshots.count)",
                caption: "Backups",
                tint: .accentColor,
                emphasis: true
            ) {
                Sparkline(values: backupTrend, height: 22)
            }
            .appearStagger(1)

            StatTile(
                symbol: "arrow.counterclockwise",
                value: lastBackup,
                caption: "Last backup",
                tint: .teal
            ) { EmptyView() }
            .hoverHelp("Backups are kept for the last 20 changes")
            .appearStagger(2)

            StatTile(
                symbol: "paintpalette",
                value: model.themes.current ?? "None",
                caption: "Active theme",
                tint: .purple
            ) {
                Text("\(model.themes.themes.count) installed")
                    .font(.badge).foregroundStyle(Color.metaText)
            }
            .appearStagger(3)
        }
    }

    static func serviceName(_ daemon: Daemon) -> String {
        switch daemon {
        case .yabai: "Window arrangement"
        case .borders: "Window outlines"
        case .sketchybar: "Menu bar"
        case .skhd: "Keyboard shortcuts"
        }
    }

    static func serviceSymbol(_ daemon: Daemon) -> String {
        switch daemon {
        case .yabai: "rectangle.3.group"
        case .borders: "square.dashed"
        case .sketchybar: "menubar.rectangle"
        case .skhd: "command"
        }
    }

    static func serviceDetail(_ daemon: Daemon) -> String {
        switch daemon {
        case .yabai: "Keeps your windows arranged across the desktop."
        case .borders: "Highlights the window you are working in."
        case .sketchybar: "Shows your custom menu bar and its widgets."
        case .skhd: "Responds to the keyboard shortcuts in your setup."
        }
    }
}
