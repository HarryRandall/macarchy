import SwiftUI

/// A colour swatch with its hex beside it, opening `ColorPickerPopover` on
/// click.
///
/// The hex is shown, not hidden behind the swatch, because these values are
/// also read and diffed as text in `theme.json`.
struct ColorWell: View {
    @Binding var color: Color
    let format: Color.MacarchyFormat
    var isUnset = false
    var onCommit: (Color) -> Void

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack(spacing: 8) {
                Text(isUnset ? "not set" : (color.macarchyString(format) ?? "—"))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(isUnset ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary))

                swatch
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.controlWell, in: RoundedRectangle(cornerRadius: 7))
            .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            ColorPickerPopover(color: $color, format: format, onCommit: onCommit)
        }
        .accessibilityLabel("Colour")
        .accessibilityValue(color.macarchyString(format) ?? "not set")
    }

    private var swatch: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(isUnset ? Color.clear : color)
            .frame(width: 20, height: 20)
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(
                        Color.cardBorder,
                        style: StrokeStyle(lineWidth: 1, dash: isUnset ? [2, 2] : []))
            )
    }
}
