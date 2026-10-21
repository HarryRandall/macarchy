import AppKit
import Macarchy

/// Keep the authored content positions while replacing overlapping native slots.
struct ComponentBoxLayout {
    static func normalising(
        _ configuration: BarConfiguration, items: [SketchybarItem]
    ) -> BarConfiguration {
        var result = configuration
        for index in result.components.indices {
            let component = result.components[index]
            guard let width = component.boxWidth, !component.isCustom
            else { continue }
            if component.hasBoxLayout {
                result.components[index] = fittingSlots(component, items: items)
                continue
            }
            let visible = component.members.filter { !$0.hasPrefix("gap.") }
                .compactMap { id in items.first { $0.id == id && $0.isOnScreen } }
                .sorted { $0.frame.minX < $1.frame.minX }
            guard !visible.isEmpty,
                visible.count == component.members.filter({ !$0.hasPrefix("gap.") }).count
            else { continue }
            let origin = visible.map { Double($0.frame.minX) }.min() ?? 0
            var target = component
            var cursor = 0.0
            for (index, observed) in visible.enumerated() {
                let item = observed.presenting(component)
                let oldOffset = observed.frame.minX - origin
                let shift = oldOffset - cursor
                var values = shiftedText(item, by: shift)
                var slot = item.width > 0 ? item.width : item.frame.width
                if let url = item.background.imageURL, let image = NSImage(contentsOf: url) {
                    slot = max(slot, ceil(image.size.width * item.background.imageScale))
                    values["background.image.padding_left"] = String(
                        (item.background.imagePaddingLeft + shift).rounded())
                }
                if index == visible.count - 1 { slot = max(1, width - cursor) }
                values["width"] = String(slot)
                values["padding_left"] = "0"
                values["padding_right"] = "0"
                for (key, value) in values {
                    if target.presentationDefaults[observed.id]?[key] == nil {
                        target.presentationDefaults[observed.id, default: [:]][key] =
                            observed.editableSettings[key]
                    }
                    target.presentation[observed.id, default: [:]][key] = value
                }
                cursor += slot
            }
            var gaps = component.members.filter { $0.hasPrefix("gap.") }
            if gaps.isEmpty { gaps = ["gap." + component.id] }
            for gap in gaps {
                target.presentation[gap] = [
                    "width": String(configuration.spacing(for: component)), "padding_left": "0",
                    "padding_right": "0"
                ]
            }
            target.members = visible.map(\.id) + gaps
            result.components[index] = fittingSlots(target, items: items)
        }
        return result
    }

    /// Each native window clips independently. Put boundaries between the parts,
    /// rather than leaving a reading inside its neighbour's allocation.
    private static func fittingSlots(
        _ component: BarComponent, items: [SketchybarItem]
    ) -> BarComponent {
        let members = component.members.filter { !$0.hasPrefix("gap.") }
        let observed = members.compactMap { id in items.first { $0.id == id && $0.isOnScreen } }
        guard observed.count == members.count, members.count > 1, let width = component.boxWidth
        else {
            return component
        }
        var cursor = 0.0
        var offsets: [String: Double] = [:]
        for item in observed {
            offsets[item.id] = cursor
            cursor += item.presenting(component).width
        }
        let geometry = ComponentGeometry(
            items: observed, component: component, sample: "Widest", offsets: offsets)
        var boundaries = [0.0]
        for index in 1..<members.count {
            let left = Set(members[..<index])
            let right = Set(members[index...])
            let lower =
                geometry.parts.filter { left.contains($0.member) }.map { Double($0.frame.maxX) }
                .max()
                ?? (boundaries.last ?? 0)
            let upper =
                geometry.parts.filter { right.contains($0.member) }.map { Double($0.frame.minX) }
                .min() ?? width
            let minimum = max(ceil(lower), (boundaries.last ?? 0) + 1)
            let maximum = min(floor(upper), width - Double(members.count - index))
            // Overlapping authored parts cannot share a clipping boundary.
            guard minimum <= maximum else { return component }
            boundaries.append(min(max(offsets[members[index]] ?? 0, minimum), maximum))
        }
        boundaries.append(width)
        var result = component
        for (index, observed) in observed.enumerated() {
            let shift = (offsets[observed.id] ?? 0) - boundaries[index]
            let slot = boundaries[index + 1] - boundaries[index]
            guard shift != 0 || slot != observed.presenting(component).width else { continue }
            let item = observed.presenting(component)
            var values = shiftedText(item, by: shift)
            values["width"] = String(slot)
            if item.background.imageURL != nil {
                values["background.image.padding_left"] = String(
                    (item.background.imagePaddingLeft + shift).rounded())
            }
            result.presentation[observed.id, default: [:]].merge(values) { _, new in new }
        }
        return result
    }
    static func applyingPaddingChange(
        _ configuration: BarConfiguration, from old: BarConfiguration, items: [SketchybarItem]
    ) -> BarConfiguration {
        var result = configuration
        for index in result.components.indices {
            let component = result.components[index]
            guard component.hasBoxLayout,
                let previous = old.components.first(where: { $0.id == component.id }),
                previous.hasBoxLayout
            else { continue }
            let delta = configuration.padding(for: component) - old.padding(for: previous)
            guard delta != 0 else { continue }
            let members = items.filter { component.members.contains($0.id) && $0.isOnScreen }
            let parts = ComponentGeometry(items: members, component: component).parts
            result.components[index] = ComponentMovement.moving(
                items: members, component: component, ids: Set(parts.map(\.id)),
                delta: CGSize(width: delta, height: 0))
        }
        return result
    }

    private static func shiftedText(_ item: SketchybarItem, by shift: Double) -> [String: String] {
        var values = ComponentGeometry.positionedText(item)
        for name in ["icon", "label"] {
            if let x = Double(values[name + ".padding_left"] ?? "") {
                values[name + ".padding_left"] = String((x + shift).rounded())
                if values[name + ".align"] == "right",
                    let right = Double(values[name + ".padding_right"] ?? "")
                {
                    values[name + ".padding_right"] = String((right - shift).rounded())
                }
            }
        }
        return values
    }

}
