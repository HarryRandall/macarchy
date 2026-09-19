import Foundation

enum Pane: String, CaseIterable, Identifiable, Hashable {
    case themes, borders, menuBar, layout, rules, shortcuts, advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .themes: "Themes"
        case .borders: "Borders"
        case .menuBar: "Menu Bar"
        case .layout: "Layout"
        case .rules: "Rules"
        case .shortcuts: "Shortcuts"
        case .advanced: "Advanced"
        }
    }

    var symbol: String {
        switch self {
        case .themes: "paintpalette"
        case .borders: "square.dashed"
        case .menuBar: "menubar.rectangle"
        case .layout: "rectangle.3.group"
        case .rules: "flag"
        case .shortcuts: "command"
        case .advanced: "gearshape"
        }
    }

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
            case .system: [.advanced]
            }
        }
    }
}
