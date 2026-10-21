import Macarchy
import SwiftUI

extension ThemeSwitcherView {
    @ViewBuilder
    func rowView(_ row: Row) -> some View {
        switch row {
        case .backgrounds:
            SwitcherRow(selected: selection == row) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 22)
            } title: {
                Text("Switch Background")
                Text(activeTheme?.title ?? "").foregroundStyle(.secondary)
            } accessories: {
                Text("\(backgroundCount(activeTheme)) options").foregroundStyle(.secondary)
            }
        case .theme(let name):
            if let theme = model.themes.themes.first(where: { $0.name == name }) {
                SwitcherRow(selected: selection == row) {
                    Circle().strokeBorder(theme.ringColour, lineWidth: 2.2)
                        .frame(width: 18, height: 18)
                        .frame(width: 22)
                } title: {
                    Text(theme.title)
                } accessories: {
                    if theme.name == model.themes.current {
                        Text("active")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.green)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(
                                Color.green.opacity(0.16), in: RoundedRectangle(cornerRadius: 5))
                    }
                    Image(systemName: theme.isDark ? "moon" : "sun.max")
                        .foregroundStyle(.secondary)
                    let count = backgroundCount(theme)
                    if count > 0 { Text("\(count) bg").foregroundStyle(.secondary) }
                }
            }
        }
    }

    var previewTheme: InstalledTheme? {
        switch selection {
        case .theme(let name): model.themes.themes.first { $0.name == name }
        default: activeTheme
        }
    }

    func backgroundCount(_ theme: InstalledTheme?) -> Int {
        theme.map { SwitcherBackground.all(in: $0).count } ?? 0
    }
}
