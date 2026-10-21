import AppKit
import Macarchy
import SwiftUI

/// The theme detail dialog.
///
/// A view in its own right rather than a property of `ThemesPane`. Presenting
/// the pane's own `editor` captured a copy of the pane struct and dropped it
/// into the modal overlay, where SwiftUI gave its `@State` fresh storage —
/// so the dialog's tab and draft lived in a different place from the ones its
/// buttons wrote to, and half the controls did nothing.
struct ThemeEditor: View {
    @Environment(AppModel.self) private var model
    let themeID: InstalledTheme.ID
    let close: () -> Void

    @State private var draft: Theme?
    @State private var tab: Tab = .look
    @State private var error: String?

    private enum Tab: String, CaseIterable {
        case look = "Look"
        case wallpaper = "Wallpaper"
        case colours = "Colours"
    }

    private var theme: InstalledTheme? {
        model.themes.themes.first { $0.id == themeID }
    }

    private var isCurrent: Bool { theme?.name == model.themes.current }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ZStack {
                SegmentedPill(
                    selection: $tab.animation(Motion.snappy),
                    options: Tab.allCases.map { .init($0, $0.rawValue) },
                    isProminent: true
                )
                HStack {
                    Spacer()
                    if let theme {
                        Button(
                            model.themes.isApplying ? "Applying…" : isCurrent ? "Reapply" : "Apply"
                        ) {
                            Task { await model.themes.apply(theme) }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.themes.isApplying)
                        .hoverHelp(
                            isCurrent
                                ? "Apply your edits to the desktop" : "Switch to this theme")
                    }
                }
            }
            .padding(.horizontal, Metrics.xl)
            .padding(.top, Metrics.medium)

            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.cardGap) {
                    if let theme {
                        switch tab {
                        case .look: look(theme)
                        case .wallpaper: wallpaper(theme)
                        case .colours: colours(theme)
                        }
                    }
                    if let message = error ?? model.themes.lastError {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.meta).foregroundStyle(.orange)
                    }
                }
                .padding(Metrics.xl)
            }
        }
        .frame(width: 620, height: 620)
        .background(Color.paneBackground)
        .motion(Motion.snappy, value: tab)
        .task(id: themeID) { draft = theme?.manifest ?? theme.map { Theme(name: $0.name) } }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Metrics.medium) {
            if let theme {
                RoundedRectangle(cornerRadius: Metrics.radiusControl, style: .continuous)
                    .fill(theme.accent)
                    .frame(width: 32, height: 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: Metrics.radiusControl, style: .continuous)
                            .strokeBorder(Color.cardBorder, lineWidth: 1))
            }
            Text(theme?.name ?? "Theme").font(.sectionTitle)

            Spacer(minLength: Metrics.medium)

            if let theme {
                IconMenu(symbol: "ellipsis", help: "More actions") {
                    if model.themes.isModified(theme) {
                        Button("Reset to shipped version") { reset(theme) }
                    }
                    Button("Export as a folder…") { runExport(theme) }
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([theme.directory])
                    }
                }
            }

            CloseButton(action: close)
        }
        .padding(Metrics.xl)
    }

    // MARK: - Tabs

    @ViewBuilder
    private func look(_ theme: InstalledTheme) -> some View {
        DesktopArtwork(
            accent: theme.accent, wallpaper: theme.wallpaperURL,
            palette: theme.palette, height: 200
        )
        .clipShape(RoundedRectangle(cornerRadius: Metrics.radiusCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.radiusCard, style: .continuous)
                .strokeBorder(Color.cardBorder, lineWidth: 1))

        if let palette = theme.palette {
            TerminalWindow(
                title: "\(theme.name) — zsh", accent: theme.accent,
                background: palette.background
            ) {
                TerminalPreview(palette: palette, themeName: theme.name, compact: true)
            }
        }
    }

    @ViewBuilder
    private func wallpaper(_ theme: InstalledTheme) -> some View {
        let backgrounds = theme.availableBackgrounds
        if backgrounds.isEmpty {
            ContentUnavailableView(
                "No wallpapers", systemImage: "photo",
                description: Text("This theme ships without one."))
        } else {
            SettingsCard("Wallpaper", help: "\(backgrounds.count) ship with this theme") {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 150), spacing: Metrics.small)],
                    spacing: Metrics.small
                ) {
                    ForEach(backgrounds, id: \.self) { url in
                        wallpaperChoice(url, in: theme)
                    }
                }
                .padding(Metrics.medium)
            }
        }
    }

    private func wallpaperChoice(_ url: URL, in theme: InstalledTheme) -> some View {
        let isChosen = url.lastPathComponent == theme.wallpaperURL?.lastPathComponent
        return Button {
            choose(url, in: theme)
        } label: {
            WallpaperThumbnail(url: url, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: Metrics.radiusSmall, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Metrics.radiusSmall, style: .continuous)
                        .strokeBorder(
                            isChosen ? Color.accentColor : Color.cardBorder,
                            lineWidth: isChosen ? 2 : 1))
        }
        .buttonStyle(InteractiveButtonStyle(cornerRadius: Metrics.radiusSmall))
        .accessibilityLabel(url.lastPathComponent)
        .accessibilityAddTraits(isChosen ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private func colours(_ theme: InstalledTheme) -> some View {
        SettingsCard("Colours", help: "Saved to theme.json as you edit.") {
            SettingRow("Dark mode") {
                Toggle("Dark mode", isOn: darkBinding(theme)).labelsHidden().toggleStyle(.switch)
            }
            colourRow("Border active", \.colors.borderActive, .argb, theme)
            colourRow("Border inactive", \.colors.borderInactive, .argb, theme)
            colourRow("Menu bar background", \.colors.sketchybarBar, .argb, theme)
            colourRow("Menu bar text", \.colors.sketchybarText, .argb, theme)
            colourRow("Firefox accent", \.colors.firefoxAccent, .rgb, theme)
            NeovimColourschemeRow(draft: $draft) { edited in save(edited, to: theme) }
        }
    }

    private func colourRow(
        _ label: String,
        _ keyPath: WritableKeyPath<Theme, String?>,
        _ format: Color.MacarchyFormat,
        _ theme: InstalledTheme
    ) -> some View {
        let raw = draft?[keyPath: keyPath]
        return SettingRow(label) {
            ColorWell(
                color: Binding(
                    get: { Color(macarchyHex: raw) ?? .clear },
                    set: { value in
                        guard var edited = draft, let encoded = value.macarchyString(format)
                        else { return }
                        edited[keyPath: keyPath] = encoded
                        draft = edited
                        save(edited, to: theme)
                    }
                ),
                format: format,
                isUnset: raw == nil
            ) { _ in }
        }
    }

    private func darkBinding(_ theme: InstalledTheme) -> Binding<Bool> {
        Binding(
            get: { draft?.dark ?? false },
            set: { value in
                guard var edited = draft else { return }
                edited.dark = value
                draft = edited
                save(edited, to: theme)
            })
    }

    // MARK: - Actions

    private func choose(_ url: URL, in theme: InstalledTheme) {
        let relative = String(url.path.dropFirst(theme.directory.path.count + 1))
        Task {
            let result = await ThemeApplication(integrations: model.backend).chooseWallpaper(
                theme: theme.name, path: relative)
            model.log.record(result)
            model.themes.reload()
            error = result.ok ? nil : result.summary
        }
    }

    private func save(_ manifest: Theme, to theme: InstalledTheme) {
        do {
            try model.themes.save(manifest, to: theme.directory)
            error = nil
        } catch { self.error = error.localizedDescription }
    }

    private func reset(_ theme: InstalledTheme) {
        do {
            try model.themes.resetToDefault(theme)
            draft = model.themes.themes.first { $0.name == theme.name }?.manifest
            error = nil
        } catch { self.error = error.localizedDescription }
    }

    private func runExport(_ theme: InstalledTheme) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = theme.name
        panel.prompt = "Export"
        panel.message = "Export \(theme.name) as a portable theme folder"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try model.themes.exportTheme(theme, to: url)
            error = nil
        } catch { self.error = error.localizedDescription }
    }
}
