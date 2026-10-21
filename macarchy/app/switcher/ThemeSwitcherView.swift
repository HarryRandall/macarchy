import Macarchy
import SwiftUI

/// The switcher's contents: a searchable theme list, a preview of the
/// selected theme, and an action bar, laid out like the Raycast command it
/// replaces.
struct ThemeSwitcherView: View {
    @Environment(AppModel.self) var model
    let close: () -> Void

    enum Row: Hashable {
        case backgrounds
        case theme(String)
    }

    enum Mode: Equatable {
        case themes
        case backgrounds(String)
    }

    @State var search = ""
    @State var selection: Row?
    @State var mode: Mode = .themes
    @State var showingActions = false
    @FocusState private var searchFocused: Bool

    private var themes: [InstalledTheme] {
        let preferred = ["awakening", "lumon"]
        let all = model.themes.themes.sorted {
            let left = preferred.firstIndex(of: $0.name) ?? preferred.count
            let right = preferred.firstIndex(of: $1.name) ?? preferred.count
            return (left, $0.name) < (right, $1.name)
        }
        guard !search.isEmpty else { return all }
        return all.filter { $0.title.localizedCaseInsensitiveContains(search) }
    }

    var activeTheme: InstalledTheme? {
        model.themes.themes.first { $0.name == model.themes.current } ?? model.themes.themes.first
    }

    var rows: [Row] {
        let showBackgrounds =
            activeTheme != nil
            && (search.isEmpty || "switch background".localizedCaseInsensitiveContains(search))
        return (showBackgrounds ? [.backgrounds] : []) + themes.map { .theme($0.name) }
    }

    var body: some View {
        VStack(spacing: 0) {
            SwitcherSearchBar(
                text: $search, placeholder: placeholder, focused: $searchFocused,
                back: back)
            Divider().opacity(0.6)
            Group {
                switch mode {
                case .themes: themeContent
                case .backgrounds(let name):
                    if let theme = model.themes.themes.first(where: { $0.name == name }) {
                        BackgroundGrid(
                            theme: theme, search: search, apply: { useBackground($0, of: theme) })
                    }
                }
            }
            .frame(maxHeight: .infinity)
            Divider().opacity(0.6)
            SwitcherFooter(
                title: "Switch Theme", primary: primaryTitle,
                showActions: { showingActions.toggle() })
        }
        .background(SwitcherBackdrop())
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
        .overlay(alignment: .bottomTrailing) {
            if showingActions {
                SwitcherActions(actions: actions) { showingActions = false }
                    .padding(.trailing, 10).padding(.bottom, 46)
                    .transition(
                        .opacity.combined(with: .scale(scale: 0.97, anchor: .bottomTrailing)))
            }
        }
        .animation(.easeOut(duration: 0.12), value: showingActions)
        .background(shortcuts)
        .onAppear {
            searchFocused = true
            selection =
                rows.first {
                    if case .theme(model.themes.current ?? "") = $0 { true } else { false }
                }
                ?? rows.first
        }
        .onChange(of: search) { _, _ in
            if mode == .themes, !rows.contains(where: { $0 == selection }) {
                selection = rows.first
            }
        }
        .onKeyPress(.upArrow) {
            move(-1, grid: -2); return .handled
        }
        .onKeyPress(.downArrow) {
            move(1, grid: 2); return .handled
        }
        .onKeyPress(.leftArrow) { gridStep(-1) }
        .onKeyPress(.rightArrow) { gridStep(1) }
        .onKeyPress(.return) {
            primary(); return .handled
        }
        .onKeyPress(.escape) {
            if showingActions { showingActions = false } else { back() }
            return .handled
        }
    }

    // MARK: - Theme list and preview

    var themeContent: some View {
        HStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(rows, id: \.self) { row in
                            rowView(row)
                                .id(row)
                                .onTapGesture { selection = row }
                                .simultaneousGesture(
                                    TapGesture(count: 2).onEnded {
                                        selection = row; primary()
                                    })
                        }
                    }
                    .padding(8)
                }
                .onChange(of: selection) { _, row in
                    if let row { proxy.scrollTo(row) }
                }
            }
            .frame(width: 340)
            Divider().opacity(0.6)
            SwitcherPreview(theme: previewTheme, showsDetails: selection != .backgrounds)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .overlay {
            if rows.isEmpty {
                Text(model.themes.themes.isEmpty ? "No themes installed" : "No matching themes")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Actions

    private var placeholder: String {
        if case .backgrounds = mode { return "Search backgrounds..." }
        return "Search themes..."
    }

    private var primaryTitle: String {
        if case .backgrounds = mode { return "Use Background" }
        return selection == .backgrounds ? "Open Backgrounds" : "Apply Theme"
    }

    private var actions: [SwitcherActions.Item] {
        var items: [SwitcherActions.Item] = [
            .init(title: primaryTitle, symbol: "return", keys: ["↵"]) { primary() }
        ]
        if mode == .themes, case .theme(let name) = selection {
            items.append(
                .init(title: "Switch Background", symbol: "photo.on.rectangle", keys: ["⌘", "B"]) {
                    openBackgrounds(name)
                })
        }
        items.append(
            .init(title: "Refresh Themes", symbol: "arrow.clockwise", keys: ["⌘", "R"]) {
                model.themes.reload()
            })
        items.append(
            .init(title: "Open Macarchy", symbol: "gearshape", keys: ["⌘", ","]) { openMacarchy() })
        return items
    }

    /// Hidden buttons give the panel its command shortcuts.
    private var shortcuts: some View {
        Group {
            Button("") { showingActions.toggle() }.keyboardShortcut("k", modifiers: .command)
            Button("") {
                if case .theme(let name) = selection { openBackgrounds(name) }
            }
            .keyboardShortcut("b", modifiers: .command)
            Button("") { model.themes.reload() }.keyboardShortcut("r", modifiers: .command)
            Button("") { openMacarchy() }.keyboardShortcut(",", modifiers: .command)
        }
        .opacity(0)
        .allowsHitTesting(false)
    }

    /// The search field keeps focus, so arrows arrive here and are routed to
    /// the list or, while picking a background, to the grid.
    private func move(_ step: Int, grid: Int) {
        if case .backgrounds = mode {
            NotificationCenter.default.post(name: .switcherStep, object: grid)
            return
        }
        guard !rows.isEmpty else { return }
        let index = selection.flatMap { rows.firstIndex(of: $0) } ?? -1
        selection = rows[min(max(index + step, 0), rows.count - 1)]
    }

    private func gridStep(_ offset: Int) -> KeyPress.Result {
        guard case .backgrounds = mode else { return .ignored }
        NotificationCenter.default.post(name: .switcherStep, object: offset)
        return .handled
    }

    private func primary() {
        showingActions = false
        switch (mode, selection) {
        case (.backgrounds, _):
            NotificationCenter.default.post(name: .switcherUseBackground, object: nil)
        case (.themes, .backgrounds?): if let activeTheme { openBackgrounds(activeTheme.name) }
        case (.themes, .theme(let name)?):
            if let theme = model.themes.themes.first(where: { $0.name == name }) { apply(theme) }
        default: break
        }
    }

    private func back() {
        if case .backgrounds = mode {
            mode = .themes
            search = ""
        } else {
            close()
        }
    }

    private func openBackgrounds(_ name: String) {
        showingActions = false
        search = ""
        mode = .backgrounds(name)
    }

    private func openMacarchy() {
        close()
        NSApp.activate()
        NSApp.windows.first { $0.identifier?.rawValue == "main" || $0.title == "Macarchy" }?
            .makeKeyAndOrderFront(nil)
    }

    private func apply(_ theme: InstalledTheme) {
        let model = model
        close()
        Task {
            let result = await ThemeApplication(integrations: model.backend).apply(name: theme.name)
            model.log.record(result)
            model.themes.reload()
        }
    }

    private func useBackground(_ background: SwitcherBackground, of theme: InstalledTheme) {
        let model = model
        close()
        Task {
            let result = await ThemeApplication(integrations: model.backend).chooseWallpaper(
                theme: theme.name, path: background.relativePath)
            model.log.record(result)
            model.themes.reload()
        }
    }
}

extension Notification.Name {
    /// Return in the background grid, which owns its own selection.
    static let switcherUseBackground = Notification.Name("switcherUseBackground")
    /// Arrow keys while the background grid is showing.
    static let switcherStep = Notification.Name("switcherStep")
}

extension InstalledTheme {
    /// "city-783" reads as "City 783".
    var title: String {
        name.split(whereSeparator: { "-_ ".contains($0) })
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    /// The ring beside each theme: its ANSI blue, as the Raycast list used,
    /// falling back to the border accent.
    var ringColour: Color { palette.map { $0.ansi(4) } ?? accent }
}
