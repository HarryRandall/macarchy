import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ThemesPane: View {
    @Environment(AppModel.self) private var model

    @State private var selected: Theme.ID?
    @State private var draft: ThemeManifest?
    @State private var error: String?

    private let columns = [GridItem(.adaptive(minimum: 172), spacing: 12)]

    private var theme: Theme? {
        model.themes.themes.first { $0.id == selected }
    }

    var body: some View {
        Form {
            Section {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(model.themes.themes) { candidate in
                        ThemeCard(theme: candidate,
                                  isCurrent: candidate.name == model.themes.current,
                                  isSelected: candidate.id == selected,
                                  isModified: model.themes.isModified(candidate))
                            .onTapGesture { select(candidate) }
                            .simultaneousGesture(TapGesture(count: 2).onEnded {
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
                            .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                    } header: {
                        Text("Terminal")
                    } footer: {
                        Text("Rendered from the theme's ghostty.conf — background, foreground and all 16 ANSI colours.")
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
            if selected == nil, let current = model.themes.themes.first(where: { $0.name == model.themes.current }) {
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
                        let isChosen = url.lastPathComponent == theme.wallpaperURL?.lastPathComponent
                        WallpaperThumbnail(url: url, height: 58)
                            .frame(width: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .strokeBorder(isChosen ? Color.accentColor : Color(nsColor: .separatorColor),
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

    @ViewBuilder
    private func editorSection(_ theme: Theme) -> some View {
        @Bindable var model = model
        Section("\(theme.name) · theme.json") {
            Toggle("Dark mode", isOn: binding(\.dark))

            colorRow("Border active", \.colors.borderActive, .argb, theme)
            colorRow("Border inactive", \.colors.borderInactive, .argb, theme)
            colorRow("Menu bar background", \.colors.sketchybarBar, .argb, theme)
            colorRow("Menu bar text", \.colors.sketchybarText, .argb, theme)
            colorRow("Firefox accent", \.colors.firefoxAccent, .rgb, theme)

            LabeledContent("Neovim colorscheme") {
                TextField("", text: Binding(
                    get: { draft?.apps.nvimColorscheme ?? "" },
                    set: { newValue in
                        guard var d = draft else { return }
                        d.apps.nvimColorscheme = newValue.isEmpty ? nil : newValue
                        draft = d
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 180)
                .onSubmit { if let draft { save(draft, to: theme) } }
            }
        }
    }

    private func binding(_ keyPath: WritableKeyPath<ThemeManifest, Bool>) -> Binding<Bool> {
        Binding(
            get: { draft?[keyPath: keyPath] ?? false },
            set: { newValue in
                guard var d = draft, let theme else { return }
                d[keyPath: keyPath] = newValue
                draft = d
                save(d, to: theme)
            }
        )
    }

    @ViewBuilder
    private func colorRow(_ label: String,
                          _ keyPath: WritableKeyPath<ThemeManifest, String?>,
                          _ format: Color.MacarchyFormat,
                          _ theme: Theme) -> some View {
        let raw = draft?[keyPath: keyPath]
        LabeledContent(label) {
            HStack(spacing: 8) {
                Text(raw ?? "not set")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(raw == nil ? .tertiary : .secondary)
                ColorPicker("", selection: Binding(
                    get: { Color(macarchyHex: raw) ?? .clear },
                    set: { newValue in
                        guard var d = draft, let encoded = newValue.macarchyString(format) else { return }
                        d[keyPath: keyPath] = encoded
                        draft = d
                        save(d, to: theme)
                    }
                ), supportsOpacity: format == .argb)
                .labelsHidden()
            }
        }
    }

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
                Button("Reveal") { NSWorkspace.shared.activateFileViewerSelecting([theme.directory]) }
            }
        } footer: {
            Text(model.themes.hasDefault(theme)
                 ? "Edits write theme.json and regenerate theme.env for the shell."
                 : "This theme didn't ship with the app, so there's no default to reset to.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func save(_ manifest: ThemeManifest, to theme: Theme) {
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
            if let imported = model.themes.themes.first(where: { $0.name == name }) { select(imported) }
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

private struct ThemeCard: View {
    let theme: Theme
    let isCurrent: Bool
    let isSelected: Bool
    let isModified: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                WallpaperThumbnail(url: theme.wallpaperURL, height: 92)
                if isCurrent {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.white, .tint)
                        .shadow(radius: 2)
                        .padding(6)
                }
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(theme.accent)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().strokeBorder(.white.opacity(0.35)))
                Text(theme.name).font(.callout).lineLimit(1)
                Spacer(minLength: 0)
                if isModified {
                    Text("edited")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isSelected ? Color.accentColor : Color(nsColor: .separatorColor),
                              lineWidth: isSelected ? 2.5 : 1)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(theme.name)\(isCurrent ? ", current theme" : "")\(isModified ? ", edited" : "")")
    }
}
