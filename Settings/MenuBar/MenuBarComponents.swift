import Desktop
import Foundation

/// Brackets supply real membership; workspace items form one explicit unit.
enum MenuBarComponents {
    static func discover(_ items: [SketchybarItem]) -> [BarComponent] {
        let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        var claimed = Set<String>()
        var groups: [BarComponent] = []
        let spaces = items.filter { $0.type == "space" || $0.id.hasPrefix("space.") }
        if !spaces.isEmpty {
            groups.append(
                component("workspaces", title: "Workspaces", leaves: spaces, brackets: []))
            claimed.formUnion(spaces.map(\.id))
        }
        for bracket in items where bracket.type == "bracket" {
            var leaves = bracket.members.compactMap { byID[$0] }.filter { !claimed.contains($0.id) }
            let stem = bracket.id.replacingOccurrences(of: ".bracket", with: "")
            if let gap = byID["gap.\(stem)"], !claimed.contains(gap.id) { leaves.append(gap) }
            guard !leaves.isEmpty else { continue }
            groups.append(
                component(stem, title: title(stem), leaves: leaves, brackets: [bracket.id]))
            claimed.formUnion(leaves.map(\.id))
        }
        for item in items where item.isLeaf && !claimed.contains(item.id) {
            groups.append(component(item.id, title: title(item.id), leaves: [item], brackets: []))
        }
        return groups.sorted {
            let lhs =
                $0.members.compactMap { byID[$0] }.filter(\.isOnScreen).map(\.frame.minX).min() ?? 0
            let rhs =
                $1.members.compactMap { byID[$0] }.filter(\.isOnScreen).map(\.frame.minX).min() ?? 0
            return lhs == rhs ? $0.id < $1.id : lhs < rhs
        }
    }

    static func merge(
        _ saved: BarConfiguration?, discovered: [BarComponent], geometry: [String: String]
    ) -> BarConfiguration {
        var configuration = saved ?? BarConfiguration()
        let live = Dictionary(uniqueKeysWithValues: discovered.map { ($0.id, $0) })
        configuration.components = configuration.components.compactMap { stored in
            guard var current = live[stored.id] else { return stored.isCustom ? stored : nil }
            current.title = stored.title
            current.side = stored.side
            current.visible = stored.visible
            current.spacing = stored.spacing
            current.paddingOverride = stored.paddingOverride
            current.spacingOverride = stored.spacingOverride
            current.kind = stored.kind
            current.text = stored.text
            current.icon = stored.icon
            current.colour = stored.colour
            current.customWidth = stored.customWidth
            // Preserve natural workspace visibility while the whole group is hidden.
            if !stored.visible { current.drawing = stored.drawing }
            return current
        }
        let known = Set(configuration.components.map(\.id))
        configuration.components += discovered.filter { !known.contains($0.id) }
        configuration.geometry = geometry
        return configuration
    }

    private static func component(
        _ id: String, title: String, leaves: [SketchybarItem], brackets: [String]
    ) -> BarComponent {
        let ordered = leaves.sorted {
            if $0.isOnScreen && $1.isOnScreen { return $0.frame.minX < $1.frame.minX }
            return $0.id.localizedStandardCompare($1.id) == .orderedAscending
        }
        var component = BarComponent(
            id: id, title: title, side: leaves.first?.position ?? "left",
            members: ordered.map(\.id), brackets: brackets,
            visible: leaves.contains(where: \.drawing),
            drawing: Dictionary(uniqueKeysWithValues: leaves.map { ($0.id, $0.drawing) }))
        component.spacing = ordered.last?.paddingRight ?? 0
        return component
    }

    private static func title(_ id: String) -> String {
        switch id {
        case "cpu": "CPU"
        case "gpu": "GPU"
        case "ram": "Memory"
        case "network": "Network"
        case "calendar": "Clock"
        case "battery": "Battery"
        default: id.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}
