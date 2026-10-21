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
            VStack(spacing: Metrics.small) {
                ZStack(alignment: .topTrailing) {
                    preview
                        .frame(maxWidth: .infinity)
                        .frame(height: height)
                        .clipShape(shape)

                    if let badge {
                        Text(badge)
                            .font(.badge)
                            .padding(.horizontal, Metrics.small)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.55), in: Capsule())
                            .foregroundStyle(.white)
                            .padding(Metrics.small)
                    }
                }
                .overlay(shape.strokeBorder(Color.cardBorder, lineWidth: 1))
                .overlay(selectionRing)
                .motion(Motion.bouncy, value: isSelected)

                Text(label)
                    .font(.rowTitle)
                    .foregroundStyle(
                        isSelected ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary)
                    )
                    .lineLimit(1)
            }
            .padding(Metrics.xs)
            .contentShape(Rectangle())
        }
        // Matched to the padded label above, so the hover wash follows the
        // card's own edge instead of floating proud of it.
        .buttonStyle(InteractiveButtonStyle(cornerRadius: Metrics.radiusCard))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.radiusCard, style: .continuous)
    }

    /// Drawn just outside the preview rather than on its edge, so selection
    /// never crops a pixel of the thing it is describing.
    @ViewBuilder
    private var selectionRing: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: Metrics.radiusCard + 2, style: .continuous)
                .strokeBorder(Color.accentColor, lineWidth: 2)
                .padding(-2)
        }
    }
}
