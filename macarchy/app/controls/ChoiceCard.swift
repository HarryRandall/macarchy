import SwiftUI

/// A large, picture-first option — a theme, a wallpaper, a layout — with its
/// name underneath and a ring when chosen.
///
/// Worth the space only when the preview carries information a label cannot.
struct ChoiceCard<Preview: View>: View {
    let label: String
    let isSelected: Bool
    var badge: String?
    var height: CGFloat = 104
    let action: () -> Void
    @ViewBuilder let preview: Preview

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                ZStack(alignment: .topTrailing) {
                    preview
                        .frame(maxWidth: .infinity)
                        .frame(height: height)
                        .clipShape(shape)

                    if let badge {
                        Text(badge)
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.black.opacity(0.55), in: Capsule())
                            .foregroundStyle(.white)
                            .padding(6)
                    }
                }
                .overlay(shape.strokeBorder(Color.cardBorder, lineWidth: 1))
                .overlay(selectionRing)

                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(
                        isSelected ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary)
                    )
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
    }

    /// Drawn outside the card rather than on its edge, so selection never
    /// crops a pixel of the preview it is describing.
    @ViewBuilder
    private var selectionRing: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Color.accentColor, lineWidth: 2)
                .padding(-3)
        }
    }
}
