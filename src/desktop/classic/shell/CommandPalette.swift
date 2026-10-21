import SwiftUI

/// One field that reaches everything: the sections, the installed themes and
/// the handful of things you would otherwise go hunting through a pane for.
///
/// The sidebar's search used to filter the section list and nothing else,
/// which left everything that is not a section unreachable by typing. This
/// opens over the window instead, in the shape people already know from every
/// other command palette: type, arrow down, Return.
struct CommandPalette: View {
    @Environment(AppModel.self) private var model

    @State private var query = ""
    @State private var highlighted = 0
    @FocusState private var focused: Bool

    private struct Item: Identifiable {
        let id: String
        let title: String
        let detail: String
        let symbol: String
        let run: @MainActor () -> Void
    }

    private struct Section: Identifiable {
        let id: String
        let items: [Item]
    }

    var body: some View {
        VStack(spacing: 0) {
            field
            Divider()
            results
        }
        .frame(width: 520)
        .background(Color.cardSurface)
        .onAppear { focused = true }
        .onChange(of: query) { highlighted = 0 }
    }

    private var field: some View {
        HStack(spacing: Metrics.small) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            TextField("Search sections, themes and actions", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .focused($focused)
                .onSubmit { runHighlighted() }
                .onKeyPress(.downArrow) { move(by: 1) }
                .onKeyPress(.upArrow) { move(by: -1) }
        }
        .padding(.horizontal, Metrics.medium)
        .padding(.vertical, Metrics.medium)
    }

    @ViewBuilder
    private var results: some View {
        if flattened.isEmpty {
            Text("Nothing matches “\(query)”")
                .font(.meta)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Metrics.medium)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.small) {
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(section.id.uppercased())
                                .eyebrowStyle()
                                .padding(.horizontal, Metrics.medium)
                                .padding(.top, Metrics.xs)
                            ForEach(section.items) { item in row(item) }
                        }
                    }
                }
                .padding(.vertical, Metrics.small)
            }
            .frame(maxHeight: 340)
            .scrollIndicators(.never)
        }
    }

    private func row(_ item: Item) -> some View {
        let index = flattened.firstIndex { $0.id == item.id } ?? 0
        let isHighlighted = index == highlighted
        return Button {
            run(item)
        } label: {
            HStack(spacing: Metrics.small) {
                Image(systemName: item.symbol)
                    .font(.system(size: 13))
                    .foregroundStyle(isHighlighted ? model.interfaceAccent : .secondary)
                    .frame(width: 20)
                Text(item.title)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                Spacer(minLength: Metrics.medium)
                Text(item.detail)
                    .font(.meta)
                    .foregroundStyle(Color.metaText)
                    .lineLimit(1)
            }
            .padding(.horizontal, Metrics.medium)
            .frame(height: 30)
            .background {
                if isHighlighted {
                    RoundedRectangle(cornerRadius: Metrics.radiusControl, style: .continuous)
                        .fill(Color.primary.opacity(0.10))
                        .padding(.horizontal, Metrics.small)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Moving the pointer takes the highlight with it, so Return always
        // runs whatever is actually lit up.
        .onHover { inside in if inside { highlighted = index } }
    }

    // MARK: - Contents

    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func matches(_ text: String) -> Bool {
        trimmed.isEmpty || text.localizedCaseInsensitiveContains(trimmed)
    }

    private var sections: [Section] {
        [
            Section(id: "Sections", items: sectionItems),
            Section(id: "Themes", items: themeItems),
            Section(id: "Actions", items: actionItems)
        ].filter { !$0.items.isEmpty }
    }

    private var flattened: [Item] { sections.flatMap(\.items) }

    private var sectionItems: [Item] {
        Pane.navigationOrder.filter { matches($0.title) }.map { pane in
            Item(
                id: "pane.\(pane.rawValue)", title: pane.title, detail: "Section",
                symbol: pane.symbol
            ) {
                model.selection = pane
            }
        }
    }

    /// Themes apply straight from here — the label says so, so nothing
    /// changes the desktop without having been asked for by name.
    private var themeItems: [Item] {
        model.themes.themes.filter { matches($0.name) }.prefix(6).map { theme in
            Item(
                id: "theme.\(theme.name)", title: "Apply \(theme.name)",
                detail: theme.name == model.themes.current ? "Current" : "Theme",
                symbol: "paintpalette"
            ) {
                Task { await model.themes.apply(theme) }
            }
        }
    }

    private var actionItems: [Item] {
        var items: [Item] = []
        if matches("Console") || matches("History") || matches("Commands") {
            items.append(
                Item(
                    id: "action.console", title: "Open the console",
                    detail: "⌥⌘C", symbol: "terminal"
                ) {
                    model.consoleOpen = true
                })
        }
        if matches("Services") || matches("Daemons") || matches("Restart") {
            items.append(
                Item(
                    id: "action.services", title: "Check the services",
                    detail: "Advanced", symbol: "bolt.horizontal"
                ) {
                    model.selection = .advanced
                })
        }
        return items
    }

    // MARK: - Driving it

    private func move(by offset: Int) -> KeyPress.Result {
        guard !flattened.isEmpty else { return .ignored }
        highlighted = min(max(highlighted + offset, 0), flattened.count - 1)
        return .handled
    }

    private func runHighlighted() {
        guard flattened.indices.contains(highlighted) else { return }
        run(flattened[highlighted])
    }

    private func run(_ item: Item) {
        model.modal.dismiss()
        withAnimation(Motion.snappy) { item.run() }
    }
}
