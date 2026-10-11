import SwiftUI

/// An inline colour picker: a saturation/brightness field, a hue strip, and the
/// hex value in the same notation the file on disk uses.
///
/// macOS's own `ColorPicker` opens the system colour panel — a separate window
/// that covers the thing being recoloured and hides the hex behind a tab. These
/// values are read back out of `theme.json` as text, so the hex is the part
/// worth keeping in view.
struct ColorPickerPopover: View {
    @Binding var color: Color
    let format: Color.MacarchyFormat
    var onCommit: (Color) -> Void

    @State private var hue: Double = 0
    @State private var saturation: Double = 1
    @State private var brightness: Double = 1
    @State private var alpha: Double = 1
    @State private var hex = ""
    @State private var isEditingHex = false

    private var supportsOpacity: Bool { format == .argb }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SaturationBrightnessField(
                hue: hue,
                saturation: $saturation,
                brightness: $brightness,
                onChange: push
            )
            .frame(width: 232, height: 172)

            HueSlider(hue: $hue, onChange: push)

            if supportsOpacity {
                AlphaSlider(base: opaque, alpha: $alpha, onChange: push)
            }

            hexField
        }
        .padding(12)
        .onAppear(perform: pull)
    }

    private var hexField: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: Metrics.radiusSmall, style: .continuous)
                .fill(color)
                .frame(width: 22, height: 22)
                .overlay(
                    RoundedRectangle(cornerRadius: Metrics.radiusSmall, style: .continuous)
                        .strokeBorder(Color.cardBorder)
                )

            TextField("", text: $hex)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Color.controlWell, in: RoundedRectangle(cornerRadius: Metrics.radiusControl)
                )
                .onSubmit(applyHex)
        }
    }

    /// The current colour at full opacity — what the alpha strip fades out of.
    private var opaque: Color {
        Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    private func pull() {
        let components = ColorComponents(color)
        hue = components.hue
        saturation = components.saturation
        brightness = components.brightness
        alpha = components.alpha
        hex = color.macarchyString(format) ?? ""
    }

    private func push() {
        let updated = Color(
            hue: hue,
            saturation: saturation,
            brightness: brightness,
            opacity: supportsOpacity ? alpha : 1
        )
        color = updated
        hex = updated.macarchyString(format) ?? ""
        onCommit(updated)
    }

    /// Typed hex wins over the sliders — the field is the authoritative form,
    /// so an exact value pasted in is never rounded by a round trip.
    private func applyHex() {
        guard let parsed = Color(macarchyHex: hex) else {
            hex = color.macarchyString(format) ?? ""
            return
        }
        color = parsed
        pull()
        onCommit(parsed)
    }
}

/// sRGB hue/saturation/brightness/alpha of a `Color`, or black if it has no
/// RGB representation (a pattern or catalogue colour).
private struct ColorComponents {
    let hue: Double
    let saturation: Double
    let brightness: Double
    let alpha: Double

    init(_ color: Color) {
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else {
            hue = 0
            saturation = 0
            brightness = 0
            alpha = 1
            return
        }
        hue = rgb.hueComponent
        saturation = rgb.saturationComponent
        brightness = rgb.brightnessComponent
        alpha = rgb.alphaComponent
    }
}

/// The square. Saturation runs left to right, brightness bottom to top.
private struct SaturationBrightnessField: View {
    let hue: Double
    @Binding var saturation: Double
    @Binding var brightness: Double
    let onChange: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Color(hue: hue, saturation: 1, brightness: 1)
                LinearGradient(
                    colors: [.white, .white.opacity(0)], startPoint: .leading, endPoint: .trailing
                )
                LinearGradient(
                    colors: [.black.opacity(0), .black], startPoint: .top, endPoint: .bottom
                )

                Knob()
                    .position(
                        x: saturation * proxy.size.width,
                        y: (1 - brightness) * proxy.size.height
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: Metrics.radiusControl, style: .continuous))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        saturation = clamp(drag.location.x / proxy.size.width)
                        brightness = 1 - clamp(drag.location.y / proxy.size.height)
                        onChange()
                    }
            )
        }
    }
}

private struct HueSlider: View {
    @Binding var hue: Double
    let onChange: () -> Void

    private var spectrum: [Color] {
        stride(from: 0.0, through: 1.0, by: 1.0 / 6).map {
            Color(hue: $0, saturation: 1, brightness: 1)
        }
    }

    var body: some View {
        GeometryReader { proxy in
            LinearGradient(colors: spectrum, startPoint: .leading, endPoint: .trailing)
                .clipShape(Capsule())
                .overlay(alignment: .leading) {
                    Knob().offset(x: hue * proxy.size.width - 7)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            hue = clamp(drag.location.x / proxy.size.width)
                            onChange()
                        }
                )
        }
        .frame(width: 232, height: 14)
    }
}

private struct AlphaSlider: View {
    let base: Color
    @Binding var alpha: Double
    let onChange: () -> Void

    var body: some View {
        GeometryReader { proxy in
            Checkerboard()
                .overlay(
                    LinearGradient(
                        colors: [base.opacity(0), base],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .overlay(alignment: .leading) {
                    Knob().offset(x: alpha * proxy.size.width - 7)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            alpha = clamp(drag.location.x / proxy.size.width)
                            onChange()
                        }
                )
        }
        .frame(width: 232, height: 14)
    }
}

/// The transparency tell behind the alpha strip.
private struct Checkerboard: View {
    var body: some View {
        Canvas { context, size in
            let square: CGFloat = 5
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            var row = 0
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = row.isMultiple(of: 2) ? 0 : square
                while x < size.width {
                    let rect = CGRect(x: x, y: y, width: square, height: square)
                    context.fill(Path(rect), with: .color(.gray.opacity(0.5)))
                    x += square * 2
                }
                y += square
                row += 1
            }
        }
    }
}

private struct Knob: View {
    var body: some View {
        Circle()
            .fill(.white)
            .frame(width: 14, height: 14)
            .overlay(Circle().strokeBorder(.black.opacity(0.18), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
    }
}

private func clamp(_ value: Double) -> Double {
    min(max(value, 0), 1)
}
