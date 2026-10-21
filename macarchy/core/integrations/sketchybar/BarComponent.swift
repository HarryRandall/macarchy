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
    public var nativePadding: Double?
    public var nativeSpacing: Double?
    public var nativeTrailingPadding: Double?
    public var paddingOverride: Double?
    public var spacingOverride: Double?
    public var kind: String?
    public var text = ""
    public var icon = ""
    public var colour: String?
    public var customWidth: Double = 24
    /// Explicit width of the complete component, including overlapping members.
    public var boxWidth: Double?

    // MARK: - Appearance
    //
    // Every field below is optional or defaulted, so a menu bar saved before
    // they existed still decodes.

    /// Colour of the glyph, when it should differ from the label.
    public var iconColour: String?
    /// Fill behind the whole component.
    public var backgroundColour: String?
    public var cornerRadius: Double = 0
    /// How the reading is written out, with `{value}` standing in for it —
    /// `"{value}%"`, `"CPU {value}"`, and so on.
    public var format: String?
    /// Values the studio renders the component at, so its behaviour at the
    /// extremes can be seen without waiting for the real reading to get there.
    public var sampleValues: [String] = []
    /// Explicit presentation edits, addressed to the original native items.
    /// Scripts and subscriptions remain owned by the existing widget.
    public var presentation: [String: [String: String]] = [:]
    /// Values captured before the first edit, used by Reset and startup replay.
    public var presentationDefaults: [String: [String: String]] = [:]

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

    /// Decoded field by field so a menu bar saved before a field existed
    /// still loads.
    ///
    /// Swift's synthesised decoder ignores property defaults and insists on
    /// every key, so adding `cornerRadius` here would have made every bar
    /// saved before this version fail to decode — and a menu bar that fails to
    /// decode is a menu bar the person has to rebuild by hand.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        side = try container.decode(String.self, forKey: .side)
        members = try container.decodeIfPresent([String].self, forKey: .members) ?? []
        brackets = try container.decodeIfPresent([String].self, forKey: .brackets) ?? []
        visible = try container.decodeIfPresent(Bool.self, forKey: .visible) ?? true
        drawing = try container.decodeIfPresent([String: Bool].self, forKey: .drawing) ?? [:]
        spacing = try container.decodeIfPresent(Double.self, forKey: .spacing) ?? 0
        nativePadding = try container.decodeIfPresent(Double.self, forKey: .nativePadding)
        nativeSpacing = try container.decodeIfPresent(Double.self, forKey: .nativeSpacing)
        nativeTrailingPadding = try container.decodeIfPresent(
            Double.self, forKey: .nativeTrailingPadding)
        paddingOverride = try container.decodeIfPresent(Double.self, forKey: .paddingOverride)
        spacingOverride = try container.decodeIfPresent(Double.self, forKey: .spacingOverride)
        kind = try container.decodeIfPresent(String.self, forKey: .kind)
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? ""
        colour = try container.decodeIfPresent(String.self, forKey: .colour)
        customWidth = try container.decodeIfPresent(Double.self, forKey: .customWidth) ?? 24
        boxWidth = try container.decodeIfPresent(Double.self, forKey: .boxWidth)
        iconColour = try container.decodeIfPresent(String.self, forKey: .iconColour)
        backgroundColour = try container.decodeIfPresent(
            String.self, forKey: .backgroundColour)
        cornerRadius = try container.decodeIfPresent(Double.self, forKey: .cornerRadius) ?? 0
        format = try container.decodeIfPresent(String.self, forKey: .format)
        sampleValues = try container.decodeIfPresent([String].self, forKey: .sampleValues) ?? []
        presentation =
            try container.decodeIfPresent(
                [String: [String: String]].self, forKey: .presentation) ?? [:]
        presentationDefaults =
            try container.decodeIfPresent(
                [String: [String: String]].self, forKey: .presentationDefaults) ?? [:]
    }

    /// Authored boxes use contiguous native slots with no inherited outer padding.
    public var hasBoxLayout: Bool {
        boxWidth != nil && !isCustom
            && members.filter { !$0.hasPrefix("gap.") }.allSatisfy {
                let values = presentation[$0] ?? [:]
                return values["align"] == "left" && values["padding_left"] == "0"
                    && values["padding_right"] == "0" && Double(values["width"] ?? "") != nil
            }
    }

    public var isCustom: Bool { kind != nil }

    /// The label as it would be drawn for a given reading.
    public func rendered(_ value: String) -> String {
        guard let format, !format.isEmpty else { return value }
        return format.replacingOccurrences(of: "{value}", with: value)
    }

    /// What to render in the studio: whatever was configured, or a spread
    /// that covers empty, middling and full.
    public var samples: [String] {
        sampleValues.isEmpty ? ["0", "47", "100"] : sampleValues
    }
}
