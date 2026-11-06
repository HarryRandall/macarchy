import Foundation

extension ReadingOutputs {
    /// Where boxes go: around the current Space, every Space, all of them
    /// together, or nowhere.
    static let spaceDesigns = ["current", "every", "together", "none"]
    /// What each Space shows.
    static let spaceContents = ["numbers-and-icons", "numbers", "icons"]
    /// The outline drawn round a Space that is not the current one, as the
    /// right side's boxes are.
    static let spaceOutline = "#ffffff33"

    /// One entry per Space up to `slots`, for a widget drawn as a row. A
    /// Space that does not exist, or an empty one when those are hidden,
    /// has its item hidden; item n is always Space n, so clicking it can go
    /// straight there.
    static func spaces(
        _ reading: SpacesReading, icons: AppIcons, slots: Int, settings: [String: SettingValue]
    ) -> WidgetOutput {
        func text(_ key: String, _ fallback: String) -> String {
            if case .text(let value) = settings[key], !value.isEmpty { return value }
            return fallback
        }
        let design = text("design", "current")
        let contents = text("show", "numbers-and-icons")
        let active = text("activeColour", "accent")
        let colour = text("colour", "text")
        let most = Int(number(settings, "maxIcons", 0))
        let hideEmpty = settings["hideEmpty"] == .bool(true)
        let names = text("names", "").split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }

        var output = WidgetOutput()
        output.items = (1...max(slots, 1)).map { slot in
            var entry = WidgetOutput()
            guard let space = reading.spaces.first(where: { $0.index == slot }),
                !(hideEmpty && space.apps.isEmpty && !space.visible)
            else {
                entry.drawing = false
                return entry
            }
            entry.drawing = true
            entry.display = space.display
            let name = names.indices.contains(slot - 1) ? names[slot - 1] : ""
            entry.icon = contents == "icons" ? "" : (name.isEmpty ? String(slot) : name)
            // As the bar's Spaces always were: a space before a dash, two
            // before the apps, so the gap after the number matches.
            let lead = entry.icon?.isEmpty == false ? (space.apps.isEmpty ? " " : "  ") : ""
            entry.label =
                contents == "numbers" ? "" : lead + strip(space.apps, icons: icons, most: most)
            entry.colour = space.visible ? active : colour
            entry.iconColour = entry.colour
            switch (design, space.visible) {
            case ("current", true), ("every", true):
                entry.background = active
                entry.border = active
            case ("every", false): entry.border = spaceOutline
            case ("together", true): entry.background = active
            default: break
            }
            return entry
        }
        if design == "together" { output.border = spaceOutline }
        output.values = [
            "current": reading.spaces.filter(\.visible).map { String($0.index) }
                .joined(separator: ","),
            "count": String(reading.spaces.count)
        ]
        return output
    }

    /// The apps' glyphs, up to `most` of them followed by how many more, or a
    /// dash for a Space with none.
    static func strip(_ apps: [String], icons: AppIcons, most: Int) -> String {
        guard !apps.isEmpty else { return "—" }
        let shown = most > 0 ? Array(apps.prefix(most)) : apps
        let glyphs = shown.map(icons.glyph).joined(separator: " ")
        return apps.count > shown.count ? "\(glyphs) +\(apps.count - shown.count)" : glyphs
    }
}
