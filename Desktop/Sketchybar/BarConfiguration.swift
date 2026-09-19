import Foundation

public struct BarConfiguration: Codable, Equatable, Sendable {
    public var components: [BarComponent] = []
    public var geometry: [String: String] = [:]
    public var componentPadding: Double?
    public var componentSpacing: Double?
    public var padding: Double { componentPadding ?? 2 }
    public var spacing: Double { componentSpacing ?? 4 }
    public init() {}

    public func padding(for component: BarComponent) -> Double {
        component.paddingOverride ?? padding
    }

    public func spacing(for component: BarComponent) -> Double {
        component.spacingOverride ?? spacing
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
