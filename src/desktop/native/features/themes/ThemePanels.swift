import AppKit

/// Native destinations never cross the bridge. Tests supply temporary URLs.
struct ThemePanels {
    var importFolder: @MainActor () -> URL?
    var exportFolder: @MainActor (String) -> URL?
    var reveal: @MainActor (URL) -> Void

    static var live: ThemePanels {
        ThemePanels(
            importFolder: {
                let panel = NSOpenPanel()
                panel.canChooseDirectories = true
                panel.canChooseFiles = false
                panel.allowsMultipleSelection = false
                panel.prompt = "Import"
                panel.message = "Choose a theme folder containing theme.json"
                return panel.runModal() == .OK ? panel.url : nil
            },
            exportFolder: { name in
                let panel = NSSavePanel()
                panel.nameFieldStringValue = name
                panel.prompt = "Export"
                panel.message = "Export \(name) as a portable theme folder"
                return panel.runModal() == .OK ? panel.url : nil
            },
            reveal: { NSWorkspace.shared.activateFileViewerSelecting([$0]) })
    }
}
