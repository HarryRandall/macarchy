import Foundation

public struct BarItemGroup: Sendable {
    public let name: String
    public let prefixes: [String]
    public func owns(_ item: String) -> Bool {
        prefixes.contains { item == $0 || item.hasPrefix($0 + ".") }
    }
}

public enum BarItems {
    public static let groups: [BarItemGroup] = [
        BarItemGroup(name: "battery", prefixes: ["battery"]),
        BarItemGroup(name: "calendar", prefixes: ["calendar"]),
        BarItemGroup(name: "spaces", prefixes: ["space", "space_labels_updater"]),
        BarItemGroup(name: "system_metrics", prefixes: ["cpu", "gpu", "ram", "network", "gap"])
    ]
}
