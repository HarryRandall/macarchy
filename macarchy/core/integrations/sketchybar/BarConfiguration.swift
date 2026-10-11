import Foundation

public struct BarConfiguration: Codable, Equatable, Sendable {
    public var components: [BarComponent] = []
    public var geometry: [String: String] = [:]
    public var componentPadding: Double?
    public var componentSpacing: Double?
    public var padding: Double { componentPadding ?? 2 }
    public var spacing: Double { componentSpacing ?? 4 }
    public init() {}

    public func validate() throws {
        let numbers: [Double] =
            [padding, spacing]
            + components.flatMap { component -> [Double] in
                [
                    component.customWidth, component.boxWidth ?? 24, component.cornerRadius,
                    component.paddingOverride ?? self.padding,
                    component.spacingOverride ?? self.spacing
                ]
            }
        guard numbers.allSatisfy({ $0.isFinite && (0...1000).contains($0) }),
            Set(components.map(\.id)).count == components.count,
            components.allSatisfy({ ["left", "center", "right"].contains($0.side) })
        else { throw ConfigurationError("Invalid menu bar components or spacing") }
        let properties: Set<String> = [
            "align", "icon.width", "label.width", "icon.align", "label.align",
            "icon", "icon.font", "label.font", "icon.color", "label.color",
            "icon.drawing", "label.drawing", "icon.y_offset", "label.y_offset",
            "icon.padding_left", "icon.padding_right", "label.padding_left", "label.padding_right",
            "width", "padding_left", "padding_right", "background.color", "background.drawing",
            "background.corner_radius", "background.image", "background.image.drawing",
            "background.image.scale", "background.image.padding_left", "background.image.y_offset"
        ]
        for component in components {
            let members = Set(component.members + component.brackets)
            for map in [component.presentation, component.presentationDefaults] {
                guard Set(map.keys).isSubset(of: members),
                    map.values.allSatisfy({ Set($0.keys).isSubset(of: properties) })
                else {
                    throw ConfigurationError(
                        "Presentation edits must preserve the widget's data source")
                }
            }
        }
        var settings = SettingsDocument()
        settings.mergeLegacy(
            Dictionary(
                uniqueKeysWithValues: geometry.compactMap { key, value in
                    StartupConfiguration.envName(forBarKey: key).map { ($0, value) }
                }))
        try settings.validate()
    }

    public func padding(for component: BarComponent) -> Double {
        if component.kind == "spacer" { return 0 }
        return component.paddingOverride ?? componentPadding
            ?? (component.hasBoxLayout ? 0 : component.nativePadding ?? 0)
    }

    public func spacing(for component: BarComponent) -> Double {
        if component.kind == "spacer" { return 0 }
        return component.spacingOverride ?? componentSpacing ?? component.nativeSpacing
            ?? component.spacing
    }

    /// Reorders one component in the visual array without changing its screen area.
    public mutating func moveOne(_ id: String, direction: Int) {
        guard direction == -1 || direction == 1,
            let index = components.firstIndex(where: { $0.id == id })
        else { return }
        let peers = components.indices.filter { components[$0].side == components[index].side }
        guard let position = peers.firstIndex(of: index),
            peers.indices.contains(position + direction)
        else { return }
        components.swapAt(index, peers[position + direction])
    }

    public mutating func move(_ source: String, before target: String) {
        move([source], before: target)
    }

    public mutating func move(_ sources: Set<String>, before target: String) {
        guard !sources.contains(target),
            let destination = components.first(where: { $0.id == target })
        else { return }
        var moved = components.filter { sources.contains($0.id) }
        guard !moved.isEmpty else { return }
        for index in moved.indices { moved[index].side = destination.side }
        components.removeAll { sources.contains($0.id) }
        guard let index = components.firstIndex(where: { $0.id == target }) else { return }
        components.insert(contentsOf: moved, at: index)
    }

    public mutating func moveToSide(_ id: String, side: String) {
        moveToSide([id], side: side)
    }

    public mutating func moveToSide(_ ids: Set<String>, side: String) {
        var moved = components.filter { ids.contains($0.id) }
        for index in moved.indices { moved[index].side = side }
        components.removeAll { ids.contains($0.id) }
        components.append(contentsOf: moved)
    }
}
