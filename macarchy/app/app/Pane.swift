import Foundation

enum Pane: String, CaseIterable, Identifiable, Hashable {
    case home, workshop, plugins, themes, borders, menuBar, layout, rules, shortcuts,
        advanced, user

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .workshop: "Workshop"
        case .plugins: "Plugins"
        case .themes: "Themes"
        case .borders: "Borders"
        case .menuBar: "Menu Bar"
        case .layout: "Layout"
        case .rules: "Rules"
        case .shortcuts: "Shortcuts"
        case .advanced: "Advanced"
        case .user: "You"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .workshop: "square.grid.2x2"
        case .plugins: "puzzlepiece.extension"
        case .themes: "paintpalette"
        case .borders: "square.dashed"
        case .menuBar: "menubar.rectangle"
        case .layout: "rectangle.3.group"
        case .rules: "flag"
        case .shortcuts: "command"
        case .advanced: "gearshape"
        case .user: "person.crop.circle"
        }
    }

    /// The ungrouped panes at the top of the sidebar.
    static let overview: [Pane] = [.home, .workshop, .plugins]

    /// The sidebar top to bottom, so arrow keys can walk it.
    static let navigationOrder: [Pane] = overview + Group.allCases.flatMap(\.panes)

    /// Grouped by what you are changing, not by which daemon owns it.
    enum Group: String, CaseIterable, Identifiable {
        case appearance = "Appearance"
        case behaviour = "Behaviour"
        case system = "System"

        var id: String { rawValue }

        var panes: [Pane] {
            switch self {
            case .appearance: [.themes, .borders, .menuBar]
            case .behaviour: [.layout, .rules, .shortcuts]
            case .system: [.advanced, .user]
            }
        }
    }
}
