import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Kit

struct ThemesPane: View {
    @Environment(AppModel.self) private var model

    @State private var selected: Theme.ID?
    @State var draft: ThemeManifest?
    @State private var error: String?

    private let columns = [GridItem(.adaptive(minimum: 172), spacing: 12)]

    var theme: Theme? {
        model.themes.themes.first { $0.id == selected }
    }

    var body: some View {
        Form {
            Section {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(model.themes.themes) { candidate in
                        ThemeCard(
                            theme: candidate,
                            isCurrent: candidate.name == model.themes.current,
                            isSelected: candidate.id == selected,
                            isModified: model.themes.isModified(candidate)
                        )
                        .onTapGesture { select(candidate) }
                        .simultaneousGesture(
                            TapGesture(count: 2).onEnded {
                                Task { await model.themes.apply(candidate) }
                            })
                    }
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
            } header: {
                HStack {
                    Text("Installed")
                    Spacer()
                    Button("Import…") { runImport() }
                        .controlSize(.small)
                }
            }

            if let theme, draft != nil {
                if let palette = theme.palette {
                    Section {
                        TerminalPreview(palette: palette, themeName: theme.name)
                            .listRowInsets(
                                EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                    } header: {
                        Text("Terminal")
                    } footer: {
                        Text(
                            "Rendered from the theme's ghostty.conf — background, foreground and all 16 ANSI colours."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                backgroundSection(theme)
                editorSection(theme)
                actionsSection(theme)
            }

            if let error {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            if selected == nil,
                let current = model.themes.themes.first(where: { $0.name == model.themes.current }) {
                select(current)
            }
        }
    }

    private func select(_ candidate: Theme) {
        selected = candidate.id
        draft = candidate.manifest ?? ThemeManifest(name: candidate.name)
        error = nil
    }

    // MARK: - Background

    @ViewBuilder
    private func backgroundSection(_ theme: Theme) -> some View {
        let backgrounds = theme.availableBackgrounds
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(backgrounds, id: \.self) { url in
                        let isChosen =
                            url.lastPathComponent == theme.wallpaperURL?.lastPathComponent
                        WallpaperThumbnail(url: url, height: 58)
                            .frame(width: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .strokeBorder(
                                        isChosen
                                            ? Color.accentColor : Color(nsColor: .separatorColor),
                                        lineWidth: isChosen ? 2 : 1)
                            )
                            .help(url.lastPathComponent)
                            .onTapGesture { chooseBackground(url, in: theme) }
                    }
                }
                .padding(.vertical, 2)
            }
            .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
        } header: {
            Text("Background · \(backgrounds.count) available")
        }
    }

    private func chooseBackground(_ url: URL, in theme: Theme) {
        guard var draft else { return }
        // Store the path relative to the theme, so the folder stays portable.
        let relative = url.path.replacingOccurrences(of: theme.directory.path + "/", with: "")
        draft.wallpaper = relative
        self.draft = draft
        save(draft, to: theme)
    }

    // MARK: - Editor

    // MARK: - Actions

    @ViewBuilder
    private func actionsSection(_ theme: Theme) -> some View {
        Section {
            HStack {
                Button("Apply \(theme.name)") { Task { await model.themes.apply(theme) } }
                    .disabled(theme.name == model.themes.current)

                if model.themes.isModified(theme) {
                    Button("Reset to default") { reset(theme) }
                }

                Spacer()

                Button("Export…") { runExport(theme) }
                Button("Open theme.json") { NSWorkspace.shared.open(theme.manifestURL) }
                Button("Reveal") {
                    NSWorkspace.shared.activateFileViewerSelecting([theme.directory])
                }
            }
        } footer: {
            Text(
                model.themes.hasDefault(theme)
                    ? "Edits write theme.json and regenerate theme.env for the shell."
                    : "This theme didn't ship with the app, so there's no default to reset to."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    func save(_ manifest: ThemeManifest, to theme: Theme) {
        do {
            try model.themes.save(manifest, to: theme.directory)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func reset(_ theme: Theme) {
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

    private func runExport(_ theme: Theme) {
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
