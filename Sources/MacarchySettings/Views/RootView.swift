import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        NavigationSplitView {
            List(selection: $model.selection) {
                ForEach(Pane.Group.allCases) { group in
                    Section(group.rawValue) {
                        ForEach(group.panes) { pane in
                            Label(pane.title, systemImage: pane.symbol).tag(pane)
                        }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 200, max: 240)
            .safeAreaInset(edge: .bottom) { DaemonFooter() }
        } detail: {
            VStack(spacing: 0) {
                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                ConsoleBar()
            }
            .navigationTitle(model.selection?.title ?? "Macarchy Settings")
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch model.selection {
        case .layout: LayoutPane()
        case .themes: ThemesPane()
        case .advanced: AdvancedPane()
        case .borders: BordersPane()
        case .menuBar: MenuBarPane()
        case .rules: StubPane(pane: .rules, note: "float_state.json merged with yabai -m rule --list.")
        case .shortcuts: StubPane(pane: .shortcuts, note: "A read-only view of the 86 skhd bindings, grouped by section comment.")
        case nil: ContentUnavailableView("Select a section", systemImage: "sidebar.left")
        }
    }
}

private struct DaemonFooter: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: allRunning ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(allRunning ? .green : .orange)
                .font(.caption)
            Text("\(model.daemons.runningCount) of \(Daemon.allCases.count) running")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var allRunning: Bool { model.daemons.runningCount == Daemon.allCases.count }
}

/// Placeholder for panes not yet wired, so the navigation is complete from day one.
struct StubPane: View {
    let pane: Pane
    let note: String

    var body: some View {
        ContentUnavailableView {
            Label(pane.title, systemImage: pane.symbol)
        } description: {
            Text(note)
        }
    }
}
