import Foundation

/// Moving a whole bar from before the widget bar onto widgets, as setup does
/// once for every earlier install. Only widgets and the items Macarchy draws
/// itself (text and spacers) are left, since nothing else runs any more.
extension WidgetMigration {
    /// What moving a bar did, for setup's report.
    public struct BarMove: Equatable, Sendable {
        public var configuration: BarConfiguration
        public var newWidgets: [NewWidget]
        /// Items that now show a built-in widget, by title.
        public var replaced: [String] = []
        /// Hidden items an earlier bar left behind, which nothing shows any more.
        public var removed: [String] = []
        /// Items whose widget was on the bar already, so it is not added twice.
        public var duplicates: [String] = []
        /// Items the bar's own scripts made that no widget replaces.
        public var unmatched: [String] = []
        /// Whether the bar starts from `BarConfiguration.widgetDefault`, as
        /// when nothing was saved or nothing saved could become a widget.
        public var startedFromDefault = false
    }

    public static func moveBar(
        _ configuration: BarConfiguration?, catalogue: WidgetCatalogue = WidgetCatalogue()
    ) -> BarMove {
        moveBar(configuration, taken: catalogue.takenIDs())
    }

    /// The move itself, given the widget ids already in use.
    static func moveBar(_ configuration: BarConfiguration?, taken: Set<String>) -> BarMove {
        let fallback = BarConfiguration.widgetDefault
        guard let configuration else {
            return BarMove(configuration: fallback, newWidgets: [], startedFromDefault: true)
        }
        func native(_ component: BarComponent) -> Bool {
            !component.isWidget && !component.isCustom
        }
        var bar = configuration
        var move = BarMove(configuration: bar, newWidgets: [])
        move.removed = bar.components.filter { native($0) && !$0.visible }.map(\.title)
        bar.components.removeAll { native($0) && !$0.visible }
        // Each widget once: an item whose widget is already on the bar, or
        // that a second item replaces too (`ram` and `memory`), goes.
        var shown = Set(bar.components.compactMap(\.widget))
        bar.components = bar.components.filter { component in
            guard native(component), let widget = replacements[component.id] else { return true }
            guard shown.insert(widget).inserted else {
                move.duplicates.append(component.title)
                return false
            }
            move.replaced.append(component.title)
            return true
        }
        let migrated = migrate(bar, taken: taken)
        bar = migrated.configuration
        move.newWidgets = migrated.newWidgets
        move.unmatched = bar.components.filter(native).map(\.title)
        bar.components.removeAll(where: native)
        if !bar.components.contains(where: \.isWidget) {
            let kept = Set(bar.components.map(\.id))
            bar.components =
                fallback.components.filter { !kept.contains($0.id) } + bar.components
            move.startedFromDefault = true
        }
        bar.geometry = fallback.geometry.merging(bar.geometry) { _, saved in saved }
        move.configuration = bar
        return move
    }
}
