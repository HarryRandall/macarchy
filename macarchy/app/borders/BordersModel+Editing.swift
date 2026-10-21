import Macarchy

extension BordersModel {
    func appearance(theme: InstalledTheme?) -> BorderAppearance {
        var appearance = BorderAppearance()
        appearance.width = width
        appearance.visible = visible
        appearance.excludedApps = excludedApps
        appearance.radius = hasCornerRadiusOverride ? cornerRadius : nil
        appearance.activeColour = theme?.manifest?.colors.borderActive
        appearance.inactiveColour = theme?.manifest?.colors.borderInactive
        return appearance
    }

    func commit(_ appearance: BorderAppearance, themes: ThemeCatalog) async throws {
        guard let theme = themes.themes.first(where: { $0.name == themes.current }) else {
            throw BorderApplyError(message: "The active theme is unavailable.")
        }
        try await BorderEdit.apply(appearance, directory: theme.directory, integrations: backend)
        themes.reload()
        await hydrate()
    }
}
