import Macarchy
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
        for item in items
        where item.isLeaf && !claimed.contains(item.id) && !item.id.hasPrefix("gap.") {
            let gap = byID["gap." + item.id]
            groups.append(
                component(
                    item.id, title: title(item.id), leaves: [item] + (gap.map { [$0] } ?? []),
                    brackets: []))
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
        // Discovery owns what it can see on the bar right now; everything an
        // author chose comes back from the stored copy. Listing the authored
        // fields one by one meant each new one was silently dropped on the
        // next hydrate, so the direction is inverted: start from what was
        // saved, and take only the live facts from discovery.
        configuration.components = configuration.components.compactMap { stored in
            guard let current = live[stored.id] else { return stored.isCustom ? stored : nil }
            var merged = stored
            merged.members = current.members
            merged.brackets = current.brackets
            merged.nativePadding = stored.nativePadding ?? current.nativePadding
            merged.nativeSpacing = stored.nativeSpacing ?? current.nativeSpacing
            merged.nativeTrailingPadding =
                stored.nativeTrailingPadding ?? current.nativeTrailingPadding
            // Natural per-member visibility only survives while the whole
            // group is showing; a hidden group keeps what it was hidden with.
            if stored.visible { merged.drawing = current.drawing }
            return merged
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
        let content = ordered.filter { !$0.id.hasPrefix("gap.") }
        component.nativePadding = content.first?.paddingLeft ?? 0
        component.nativeTrailingPadding = content.last?.paddingRight ?? 0
        component.nativeSpacing = ordered.filter { $0.id.hasPrefix("gap.") }.reduce(0) {
            $0 + max($1.width, $1.frame.width) + $1.paddingLeft + $1.paddingRight
        }
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
