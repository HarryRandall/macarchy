import SwiftUI
import AppKit

struct ThemesPane: View {
    @Environment(AppModel.self) private var model
    @State private var selected: Theme.ID?

    private let columns = [GridItem(.adaptive(minimum: 172), spacing: 12)]

    var body: some View {
        Form {
            Section("Installed") {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(model.themes.themes) { theme in
                        ThemeCard(
                            theme: theme,
                            isCurrent: theme.name == model.themes.current,
                            isSelected: theme.id == selected
                        )
                        .onTapGesture { selected = theme.id }
                        .simultaneousGesture(
                            TapGesture(count: 2).onEnded {
                                Task { await model.themes.apply(theme) }
                            }
                        )
                    }
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
            }

            if let theme = model.themes.themes.first(where: { $0.id == selected }) {
                backgroundSection(theme)
                valuesSection(theme)

                Section {
                    HStack {
                        Button("Apply \(theme.name)") {
                            Task { await model.themes.apply(theme) }
                        }
                        .disabled(theme.name == model.themes.current)

                        Spacer()

                        Button("Open theme.json") { NSWorkspace.shared.open(theme.manifestURL) }
                        Button("Reveal") {
                            NSWorkspace.shared.activateFileViewerSelecting([theme.directory])
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { selected = selected ?? model.themes.current }
    }

    @ViewBuilder
    private func backgroundSection(_ theme: Theme) -> some View {
        let backgrounds = theme.availableBackgrounds
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(backgrounds, id: \.self) { url in
                        WallpaperThumbnail(url: url, height: 58)
                            .frame(width: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .strokeBorder(
                                        url == theme.wallpaperURL ? Color.accentColor : Color(nsColor: .separatorColor),
                                        lineWidth: url == theme.wallpaperURL ? 2 : 1)
                            )
                            .help(url.lastPathComponent)
                    }
                }
                .padding(.vertical, 2)
            }
            .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
        } header: {
            Text("Background · \(backgrounds.count) available")
        } footer: {
            Text("The active choice lives in .backgrounds.json, which overrides the WALLPAPER line in theme.env.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func valuesSection(_ theme: Theme) -> some View {
        Section("\(theme.name) · theme.json") {
            ForEach(theme.values.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                LabeledContent(Self.humanise(key)) {
                    HStack(spacing: 7) {
                        Text(value)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if let color = Color(macarchyHex: value) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(color)
                                .frame(width: 18, height: 18)
                                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.separator))
                        }
                    }
                }
            }
        }
    }

    /// BORDER_ACTIVE -> "Border active". Capitalising every word turns
    /// "colorscheme" into "Colorscheme" and reads like a label, not a constant.
    static func humanise(_ key: String) -> String {
        let words = key.lowercased().split(separator: "_").map(String.init)
        guard let first = words.first else { return key }
        return ([first.capitalized] + words.dropFirst()).joined(separator: " ")
    }
}

private struct ThemeCard: View {
    let theme: Theme
    let isCurrent: Bool
    let isSelected: Bool

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
                Text(theme.name)
                    .font(.callout)
                    .lineLimit(1)
                Spacer(minLength: 0)
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
        .accessibilityLabel("\(theme.name)\(isCurrent ? ", current theme" : "")")
    }
}
