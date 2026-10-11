import AppKit
import Macarchy
import SwiftUI

struct ShortcutsPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var shortcuts = model.shortcuts
        SettingsPage("Shortcuts") {
            SearchField(
                prompt: "Find a shortcut",
                text: $shortcuts.search,
                width: 230,
                help: "Search keys, source comments and commands")
            IconMenu(symbol: "ellipsis", help: "Shortcut actions") {
                Menu("Filters") { filterOptions }
                Divider()
                Button("Refresh shortcuts") { shortcuts.reload() }
                Button("Open configuration") {
                    NSWorkspace.shared.open(ShortcutsModel.configURL)
                }
            }
        } content: {
            HStack {
                Text(
                    shortcuts.hasFilters
                        ? "\(shortcuts.matchCount) of \(shortcuts.bindings.count) shortcuts"
                        : "\(shortcuts.bindings.count) shortcuts"
                )
                .font(.meta).foregroundStyle(.secondary)
                Spacer()
                if shortcuts.hasFilters {
                    Button("Clear filters") { shortcuts.clearFilters() }
                        .font(.meta)
                }
                HelpTooltip(
                    text: "Click a key combination to change it. Expand a row to see its command.")
            }
            if let message = shortcuts.lastError {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.meta).foregroundStyle(.orange)
            }
            if shortcuts.rows.isEmpty {
                ContentUnavailableView("No shortcuts found", systemImage: "keyboard")
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(shortcuts.rows) { row in
                        switch row.kind {
                        case .header(let title, let count):
                            HStack {
                                Text(title).font(.meta).foregroundStyle(.secondary).lineLimit(2)
                                CountBadge(count: count)
                                Spacer()
                            }
                            .padding(.horizontal, Metrics.medium).padding(.vertical, Metrics.small)
                            .background(Color.controlWell)
                        case .binding(let binding):
                            ShortcutRow(binding: binding, title: shortcuts.label(for: binding)) {
                                edit(binding)
                            }
                        }
                    }
                }
                .background(Color.cardSurface)
                .clipShape(RoundedRectangle(cornerRadius: Metrics.radiusSmall))
                .overlay(
                    RoundedRectangle(cornerRadius: Metrics.radiusSmall)
                        .strokeBorder(Color.cardBorder, lineWidth: 1))
            }
        }
        .onAppear { if model.shortcuts.bindings.isEmpty { model.shortcuts.reload() } }
    }

    private func edit(_ binding: SkhdBinding) {
        model.modal.present {
            ShortcutEditor(binding: binding) { model.modal.dismiss() }
        }
    }

    private var filterOptions: some View {
        @Bindable var shortcuts = model.shortcuts
        return Group {
            Section("Scope") {
                Picker("Scope", selection: $shortcuts.scopeFilter) {
                    ForEach(ShortcutsModel.Scope.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
            }
            Section("Modifiers") {
                ForEach(["cmd", "alt", "ctrl", "shift"], id: \.self) { modifier in
                    Toggle(
                        SkhdBinding.symbol(forModifier: modifier),
                        isOn: Binding(
                            get: { shortcuts.modifierFilter.contains(modifier) },
                            set: { _ in shortcuts.toggle(modifier) }))
                }
            }
            Section("Source group") {
                Picker("Source group", selection: $shortcuts.sectionFilter) {
                    Text("All groups").tag(String?.none)
                    ForEach(shortcuts.allSections, id: \.self) { Text($0).tag(Optional($0)) }
                }
            }
            if shortcuts.hasFilters { Button("Clear filters") { shortcuts.clearFilters() } }
        }
    }
}
