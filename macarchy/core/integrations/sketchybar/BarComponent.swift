import Foundation

/// One selectable unit. Member order is visual, from left to right.
public struct BarComponent: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var side: String
    public var members: [String]
    public var brackets: [String]
    public var visible: Bool
    public var drawing: [String: Bool]
    public var spacing: Double = 0
    public var paddingOverride: Double?
    public var spacingOverride: Double?
    public var kind: String?
    public var text = ""
    public var icon = ""
    public var colour: String?
    public var customWidth: Double = 24

    public init(
        id: String, title: String, side: String, members: [String],
        brackets: [String] = [], visible: Bool = true, drawing: [String: Bool] = [:]
    ) {
        self.id = id
        self.title = title
        self.side = side
        self.members = members
        self.brackets = brackets
        self.visible = visible
        self.drawing = drawing
    }

    public var isCustom: Bool { kind != nil }
}
