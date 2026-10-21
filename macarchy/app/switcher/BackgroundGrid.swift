import SwiftUI

/// Two columns of 16:9 wallpapers, current one first and ticked.
struct BackgroundGrid: View {
    let theme: InstalledTheme
    let search: String
    let apply: (SwitcherBackground) -> Void
    @State private var selected: SwitcherBackground.ID?

    private var backgrounds: [SwitcherBackground] {
        let all = SwitcherBackground.all(in: theme)
        let current = all.filter { $0.url == theme.wallpaperURL }
        let ordered = current + all.filter { $0.url != theme.wallpaperURL }
        guard !search.isEmpty else { return ordered }
        return ordered.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 14
            ) {
                ForEach(backgrounds) { background in
                    BackgroundTile(
                        background: background, current: background.url == theme.wallpaperURL,
                        selected: selected == background.id
                    )
                    .onTapGesture { selected = background.id }
                    .simultaneousGesture(TapGesture(count: 2).onEnded { apply(background) })
                }
            }
            .padding(14)
        }
        .overlay {
            if backgrounds.isEmpty {
                Text("No wallpapers in \(theme.title)").foregroundStyle(.secondary)
            }
        }
        .onAppear { selected = backgrounds.first?.id }
        .onReceive(NotificationCenter.default.publisher(for: .switcherStep)) { note in
            if let offset = note.object as? Int { step(offset) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switcherUseBackground)) { _ in
            if let background = backgrounds.first(where: { $0.id == selected }) {
                apply(background)
            }
        }
    }

    private func step(_ offset: Int) {
        let index = backgrounds.firstIndex { $0.id == selected } ?? 0
        let next = min(max(index + offset, 0), backgrounds.count - 1)
        if backgrounds.indices.contains(next) { selected = backgrounds[next].id }
    }
}

private struct BackgroundTile: View {
    let background: SwitcherBackground
    let current: Bool
    let selected: Bool
    @State private var image: NSImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Rectangle()
                .fill(.white.opacity(0.05))
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay {
                    if let image {
                        Image(nsImage: image).resizable().scaledToFill()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(selected ? Color.white.opacity(0.8) : .clear, lineWidth: 2)
                )
            HStack(spacing: 6) {
                Text(background.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                Spacer()
                if current {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        .help("Current")
                }
            }
        }
        .task(id: background.url) {
            image = await Thumbnails.shared.image(for: background.url, maxPixels: 700)
        }
    }
}
