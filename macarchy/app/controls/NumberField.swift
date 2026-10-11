import SwiftUI

/// A small boxed field for typing a number directly, with the unit sitting
/// outside the box so it can't be mistaken for part of the value.
///
/// Sliders are good at "a bit more"; this is for "exactly 14". Panes generally
/// offer both against the same binding.
struct NumberField: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var decimals: Int = 0
    var unit: String?
    var width: CGFloat = 58
    var onCommit: (() -> Void)?

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .monospacedDigit().font(.system(size: 12, design: .monospaced))
                .multilineTextAlignment(.center)
                .focused($isFocused)
                .frame(width: width)
                .padding(.vertical, 5)
                .background(Color.controlWell, in: field)
                .overlay(field.strokeBorder(borderColor, lineWidth: 1))
                .onSubmit(commit)
                .onChange(of: isFocused) { _, focused in if !focused { commit() } }
                .onChange(of: value) { _, new in if !isFocused { text = format(new) } }
                .onAppear { text = format(value) }

            if let unit {
                Text(unit)
                    .monospacedDigit().font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var field: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.radiusControl, style: .continuous)
    }

    private var borderColor: Color {
        isFocused ? .accentColor : .cardBorder
    }

    private func format(_ raw: Double) -> String {
        String(format: "%.\(decimals)f", raw)
    }

    /// Anything unparseable snaps back to the last good value rather than
    /// writing a zero to a live daemon setting.
    private func commit() {
        guard let parsed = Double(text.trimmingCharacters(in: .whitespaces)) else {
            text = format(value)
            return
        }
        let clamped = min(max(parsed, range.lowerBound), range.upperBound)
        text = format(clamped)
        guard clamped != value else { return }
        value = clamped
        onCommit?()
    }
}
