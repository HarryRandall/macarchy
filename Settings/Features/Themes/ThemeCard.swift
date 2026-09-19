import SwiftUI

struct ThemeCard: View {
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
                .strokeBorder(
                    isSelected ? Color.accentColor : Color(nsColor: .separatorColor),
                    lineWidth: isSelected ? 2.5 : 1)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(theme.name)\(isCurrent ? ", current theme" : "")\(isModified ? ", edited" : "")")
    }
}
