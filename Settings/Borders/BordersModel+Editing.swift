import Desktop

extension BordersModel {
    func appearance(theme: InstalledTheme?) -> BorderAppearance {
        var appearance = BorderAppearance()
        appearance.width = width
        appearance.visible = visible
        appearance.excludedApps = excludedApps
        if !appearance.excludedApps.contains("iPhone Mirroring") {
            appearance.excludedApps.append("iPhone Mirroring")
        }
        appearance.radius = hasCornerRadiusOverride ? cornerRadius : nil
        appearance.activeColour = theme?.manifest?.colors.borderActive
        appearance.inactiveColour = theme?.manifest?.colors.borderInactive
        return appearance
    }

    func commit(_ appearance: BorderAppearance, themes: ThemeCatalog) async throws {
        guard let theme = themes.themes.first(where: { $0.name == themes.current }),
            var manifest = theme.manifest
        else { throw BorderApplyError(message: "The active theme is unavailable.") }
        let coloursChanged =
            manifest.colors.borderActive != appearance.activeColour
            || manifest.colors.borderInactive != appearance.inactiveColour
        if coloursChanged {
            manifest.colors.borderActive = appearance.activeColour
            manifest.colors.borderInactive = appearance.inactiveColour
            try themes.save(manifest, to: theme.directory)
        }
        let currentRadius = hasCornerRadiusOverride ? cornerRadius : nil
        if currentRadius != appearance.radius { try await applyCornerRadius(appearance.radius) }
        width = appearance.width
        visible = appearance.visible
        excludedApps = appearance.excludedApps
        try await applyBorders()
    }
}
