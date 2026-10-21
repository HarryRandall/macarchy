import SwiftUI

/// A compact inline choice — `System · On · Off` — for settings with a handful
/// of options that are short enough to show at once.
///
/// Only the selected segment is drawn, so a row of these reads as text until
/// the eye reaches the one that is set. Use a `Picker` instead when the option
/// labels are long or the list can grow.
struct SegmentedPill<Value: Hashable>: View {
    struct Option: Identifiable {
        let value: Value
        let label: String
        /// Shown after the label, the way a tab shows how much is behind it.
        let count: Int?

        var id: Value { value }

        init(_ value: Value, _ label: String, count: Int? = nil) {
            self.value = value
            self.label = label
            self.count = count
        }
    }

    @Binding var selection: Value
    let options: [Option]
    /// Tabs heading a page need more presence than a control inside a row.
    var isProminent = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options) { option in
                segment(option)
            }
        }
    }

    private func segment(_ option: Option) -> some View {
        let isSelected = option.value == selection
        return Button {
            guard !isSelected else { return }
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.18)) {
                selection = option.value
            }
        } label: {
            HStack(spacing: 6) {
                Text(option.label)
                    .foregroundStyle(
                        isSelected ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                if let count = option.count {
                    Text(String(count))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .font(.system(size: isProminent ? 13 : 12, weight: isSelected ? .medium : .regular))
            .padding(.horizontal, isProminent ? Metrics.medium : Metrics.small)
            .padding(.vertical, isProminent ? Metrics.small - 2 : Metrics.xs)
            .background {
                if isSelected {
                    Capsule(style: .continuous)
                        .fill(Color.controlWell)
                        .matchedGeometryEffect(id: "selection", in: pill)
                }
            }
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
