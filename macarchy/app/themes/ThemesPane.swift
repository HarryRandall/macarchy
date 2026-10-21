import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Macarchy

/// The sections of the theme dialog.
enum ThemeTab: Hashable {
    case look, wallpaper, colours
}

struct ThemesPane: View {
    @Environment(AppModel.self) var model

    @State var selected: InstalledTheme.ID?
    @State var draft: Theme?
    @State var error: String?
    @State var editorTab: ThemeTab = .look

    var theme: InstalledTheme? {
        model.themes.themes.first { $0.id == selected }
    }

    private var current: InstalledTheme? {
        model.themes.themes.first { $0.name == model.themes.current }
    }

    var body: some View {
        SettingsPage("Themes", subtitle: "A familiar desktop. A different feeling.") {
            Button("Import…") { runImport() }
        } content: {
            if let current {
                HeroBanner(
                    eyebrow: "CURRENT THEME",
                    title: current.name,
                    subtitle: "Your wallpaper, palette and finishing touches."
                ) {
                    DesktopArtwork(
                        accent: current.accent, wallpaper: current.wallpaperURL,
                        palette: current.palette, height: 240)
                } trailing: {
                    Button("Customise") { openEditor(current) }
                }
                .overlay(alignment: .topTrailing) {
                    StatusChip(tone: .good, label: "Applied", live: true)
                        .padding(Metrics.medium)
                }
            }

            SectionHeading(
                "Your collection", note: "\(model.themes.themes.count) installed")

            if model.themes.themes.isEmpty {
                ContentUnavailableView(
                    "Your collection starts here", systemImage: "paintpalette",
                    description: Text("Import a theme folder to make it your own."))
            }
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 280), spacing: Metrics.gridGap)],
                spacing: Metrics.gridGap
            ) {
                ForEach(
                    Array(model.themes.themes.enumerated()), id: \.element.id
                ) { index, candidate in
                    Button {
                        openEditor(candidate)
                    } label: {
                        ThemeCard(
                            theme: candidate, isCurrent: candidate.name == model.themes.current,
                            isSelected: false, isModified: model.themes.isModified(candidate),
                            apply: { Task { await model.themes.apply(candidate) } },
                            isApplying: model.themes.isApplying)
                    }
                    .buttonStyle(.plain)
                    .hoverLift()
                    .appearStagger(index)
                }
            }

            if let message = error ?? model.themes.lastError {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.meta).foregroundStyle(.orange)
            }
        }
    }

    /// Presented inside the window, so the grid behind it goes inert.
    func openEditor(_ candidate: InstalledTheme) {
        model.modal.present {
            ThemeEditor(themeID: candidate.id) { model.modal.dismiss() }
        }
    }

    func select(_ candidate: InstalledTheme) {
        selected = candidate.id
        draft = candidate.manifest ?? Theme(name: candidate.name)
        error = nil
    }

    func chooseBackground(_ url: URL, in theme: InstalledTheme) {
        let relative = String(url.path.dropFirst(theme.directory.path.count + 1))
        do {
            try SettingsStore().update { $0.wallpapers[theme.name] = relative }
            model.themes.reload()
            if model.themes.current == theme.name { Task { await model.themes.apply(theme) } }
        } catch { self.error = error.localizedDescription }
    }

    func save(_ manifest: Theme, to theme: InstalledTheme) {
        do {
            try model.themes.save(manifest, to: theme.directory)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func reset(_ theme: InstalledTheme) {
        do {
            try model.themes.resetToDefault(theme)
            if let refreshed = model.themes.themes.first(where: { $0.name == theme.name }) {
                draft = refreshed.manifest
            }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func runImport() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Import"
        panel.message = "Choose a theme folder containing theme.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let name = try model.themes.importTheme(from: url)
            if let imported = model.themes.themes.first(where: { $0.name == name }) {
                select(imported)
            }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func runExport(_ theme: InstalledTheme) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = theme.name
        panel.prompt = "Export"
        panel.message = "Export \(theme.name) as a portable theme folder"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try model.themes.exportTheme(theme, to: url)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}
