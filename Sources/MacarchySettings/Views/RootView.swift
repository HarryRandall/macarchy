import SwiftUI
import MacarchyKit

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
        case .rules: RulesPane()
        case .shortcuts: ShortcutsPane()
        case nil: ContentUnavailableView("Select a section", systemImage: "sidebar.left")
        }
    }
}

private struct DaemonFooter: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 6) {
            Image(
                systemName: allRunning ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
            )
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
