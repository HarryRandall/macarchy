import Foundation

/// The settings window's pages, by the identifiers the React shell uses.
enum Pane: String, CaseIterable, Hashable {
    case home, workshop, plugins, themes, borders, menuBar, layout, rules, shortcuts,
        advanced, health, report
}
