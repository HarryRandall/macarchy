import Foundation
import Macarchy

extension BridgeRouter {
    /// The Menu Bar page: reads and applies through `MenuBarModel`, which
    /// owns the live readings, the saved configuration and the apply order.
    func registerMenuBar(model: AppModel) {
        register("menuBar.getState") { [weak model] (_: Empty) in
            guard let model else { throw BridgeFailure(.unavailable, "The app is closing.") }
            return await model.readMenuBar()
        }
        register("menuBar.apply") { [weak model] (params: MenuBarApplyParams) in
            guard let model else { throw BridgeFailure(.unavailable, "The app is closing.") }
            let bar = model.menuBar
            _ = await model.readMenuBar()
            if let error = bar.error { throw BridgeFailure(.operationFailed, error) }
            let configuration = try MenuBarEdits.configuration(
                from: params, over: bar.applied, catalogue: WidgetCatalogue().read())
            bar.edit { $0 = configuration }
            await bar.apply()
            StateBroadcast.shared.settingsWritten()
            if let error = bar.error {
                bar.discard()
                throw BridgeFailure(.operationFailed, error)
            }
            return model.menuBarState()
        }
    }
}

extension AppModel {
    /// Reads the bar afresh. The page keeps its own draft, so any draft the
    /// model holds is dropped first.
    func readMenuBar() async -> MenuBarState {
        menuBar.discard()
        await menuBar.hydrate()
        return menuBarState()
    }

    func menuBarState() -> MenuBarState {
        let configuration = menuBar.applied
        let readings = Dictionary(
            menuBar.items.map { ($0.id, $0.label.value) }, uniquingKeysWith: { first, _ in first })
        let items = configuration.components.map { component in
            MenuBarItemState(
                id: component.id, title: component.title,
                zone: MenuBarEdits.zone(fromSide: component.side), visible: component.visible,
                kind: component.isWidget ? "widget" : component.kind, text: component.text,
                icon: component.icon, command: component.command, interval: component.interval,
                widget: component.widget, settings: component.settings ?? [:],
                style: component.style, click: component.click,
                reading: component.isCustom
                    ? component.rendered(component.text)
                    : component.members.filter { !$0.hasPrefix("gap.") }
                        .compactMap { readings[$0] }.filter { !$0.isEmpty }
                        .joined(separator: " "))
        }
        let geometry = configuration.geometry
        return MenuBarState(
            items: items,
            bar: MenuBarSettings(
                height: Int(Double(geometry["height"] ?? "") ?? 35),
                position: geometry["position"] == "bottom" ? "bottom" : "top",
                padding: Int(Double(geometry["padding_left"] ?? "") ?? 10),
                centre: configuration.showsCentre == true),
            widgets: MenuBarWidgets.info(), widgetProblems: MenuBarWidgets.problems(),
            unavailableReason: menuBar.error)
    }
}

/// Turns the page's list back into a configuration, keeping every authored
/// detail the page does not show, such as colours and spacing.
enum MenuBarEdits {
    static let kinds: Set<String> = ["text", "spacer", "command"]

    static func zone(fromSide side: String) -> String { side == "center" ? "centre" : side }

    static func side(fromZone zone: String) throws -> String {
        switch zone {
        case "left", "right": zone
        case "centre": "center"
        default: throw BridgeFailure(.invalidParams, "There is no \(zone) zone.")
        }
    }

    static func configuration(
        from params: MenuBarApplyParams, over current: BarConfiguration,
        catalogue: WidgetCatalogue.Snapshot
    ) throws -> BarConfiguration {
        guard (16...64).contains(params.bar.height), (0...64).contains(params.bar.padding),
            ["top", "bottom"].contains(params.bar.position)
        else { throw BridgeFailure(.invalidParams, "Those bar settings are out of range.") }
        var configuration = current
        let existing = Dictionary(
            current.components.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var components: [BarComponent] = []
        for item in params.items {
            var component: BarComponent
            if let known = existing[item.id] {
                component = known
            } else if item.kind == "widget", isNewID(item.id) {
                component = BarComponent(
                    id: item.id, title: item.title, side: "left", members: [item.id])
                component.widget = item.widget
            } else {
                // Only items made on the page are new, and their id becomes a
                // SketchyBar item name.
                guard let kind = item.kind, kinds.contains(kind), isNewID(item.id) else {
                    throw BridgeFailure(.invalidParams, "\(item.title) is not on the bar.")
                }
                component = BarComponent(
                    id: item.id, title: item.title, side: "left", members: [item.id])
                component.kind = kind
                if kind == "spacer" {
                    component.customWidth = 20
                    component.boxWidth = 20
                    component.paddingOverride = 0
                    component.spacingOverride = 0
                }
            }
            component.side = try side(fromZone: item.zone)
            component.visible = item.visible
            component.title = item.title
            if component.isCustom {
                component.text = item.text
                component.icon = item.icon
                component.command = component.kind == "command" ? item.command : nil
                component.interval = component.kind == "command" ? item.interval : nil
            }
            if component.isWidget { try widgetEdits(item, into: &component, catalogue: catalogue) }
            components.append(component)
        }
        // The bar's own items cannot be removed, only hidden; one the page
        // left out keeps its place at the end of its side.
        let sent = Set(params.items.map(\.id))
        components += current.components.filter { !$0.ownsItem && !sent.contains($0.id) }
        configuration.components = components
        configuration.geometry["height"] = String(params.bar.height)
        configuration.geometry["position"] = params.bar.position
        configuration.geometry["padding_left"] = String(params.bar.padding)
        configuration.geometry["padding_right"] = String(params.bar.padding)
        configuration.showsCentre = params.bar.centre ? true : nil
        let manifests = Dictionary(
            catalogue.entries.map { ($0.id, $0.manifest) }, uniquingKeysWith: { first, _ in first })
        return WidgetLook(manifests: manifests).normalised(configuration)
    }

    /// A widget item's widget, its settings and its edits to the widget's
    /// look and click, checked against the widget. The widget can change, as
    /// when the item moves to a copy of a built-in. Edits that change
    /// nothing are dropped, so the item follows the widget if it changes.
    static func widgetEdits(
        _ item: MenuBarItemEdit, into component: inout BarComponent,
        catalogue: WidgetCatalogue.Snapshot
    ) throws {
        guard let id = item.widget, let entry = catalogue.entry(id) else {
            throw BridgeFailure(.invalidParams, "There is no widget called \(item.widget ?? "").")
        }
        component.widget = id
        let manifest = entry.manifest
        let problems =
            manifest.problems(settings: item.settings)
            + manifest.problems(style: item.style, click: item.click)
        if let problem = problems.first {
            throw BridgeFailure(.invalidParams, "\(item.title): \(problem)")
        }
        let defaults = (manifest.settings ?? [:]).compactMapValues(\.default)
        let settings = item.settings.filter { defaults[$0.key] != $0.value }
        component.settings = settings.isEmpty ? nil : settings
        component.style = item.style == WidgetStyle() ? nil : item.style
        component.click = item.click == manifest.click ? nil : item.click
    }

    /// `macarchy.` and then lower-case letters, digits and hyphens, as the
    /// page makes them.
    static func isNewID(_ id: String) -> Bool {
        guard id.hasPrefix("macarchy."), id.count > 9, id.count <= 64 else { return false }
        return id.dropFirst(9).allSatisfy {
            $0.isASCII && ($0.isLowercase || $0.isNumber || $0 == "-")
        }
    }
}
