import SwiftUI

/// A slider with the value typeable beside it.
///
/// Both halves write the same binding: drag when you want to feel the change,
/// type when you already know the number. `onChange` fires continuously from
/// the slider, so callers that talk to a daemon should already be debounced.
struct ValueSlider: View {
    @Environment(AppModel.self) private var model
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    var decimals: Int = 0
    var unit: String?
    var sliderWidth: CGFloat = 148
    var onChange: (Double) -> Void

    private var quantisedValue: Binding<Double> {
        Binding(
            get: { value },
            set: { proposed in
                let rounded =
                    range.lowerBound
                    + ((proposed - range.lowerBound) / step).rounded() * step
                value = min(max(rounded, range.lowerBound), range.upperBound)
            }
        )
    }

    var body: some View {
        HStack(spacing: 10) {
            Slider(value: quantisedValue, in: range)
                .tint(model.interfaceAccent)
                .accentColor(model.interfaceAccent)
                .hoverHelp("Drag to adjust, or type an exact value")
                .frame(width: sliderWidth)
                .onChange(of: value) { _, new in onChange(new) }

            NumberField(
                value: $value,
                range: range,
                decimals: decimals,
                unit: unit
            )
        }
    }
}
