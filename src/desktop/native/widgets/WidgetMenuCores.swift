import Macarchy
import SwiftUI

/// Use per core as numbered cells, performance in blue and efficiency in
/// teal, stronger the busier, in even rows that fill the width. Pointing at
/// a cell outlines it and names the core.
struct MenuCores: View {
    let caption: String
    let groups: [[Double]]
    let pointer: CGPoint?
    @State private var frames: [Int: CGRect] = [:]

    private var hovered: Int? {
        guard let pointer else { return nil }
        return frames.first(where: { $0.value.insetBy(dx: -2, dy: -2).contains(pointer) })?.key
    }

    var body: some View {
        let hovered = self.hovered
        let all = groups.flatMap { $0 }
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(caption.isEmpty ? "Cores" : caption)
                Spacer()
                if !all.isEmpty {
                    Text("\(Int((all.reduce(0, +) / Double(all.count)).rounded()))% average")
                        .monospacedDigit()
                }
            }
            .font(.system(size: 11)).foregroundStyle(.secondary)
            VStack(spacing: 8) {
                ForEach(Array(groups.enumerated()), id: \.offset) { group, values in
                    let other = groups.indices.contains(1 - group) ? groups[1 - group].count : 0
                    grid(
                        group: group, values: values,
                        columns: WidgetMenu.coreColumns(values.count, other: other),
                        hovered: hovered)
                }
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 2)
    }

    private func grid(group: Int, values: [Double], columns: Int, hovered: Int?) -> some View {
        let rows = stride(from: 0, to: values.count, by: columns).map {
            Array(values.indices[$0..<min($0 + columns, values.count)])
        }
        return VStack(spacing: 4) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 4) {
                    ForEach(row, id: \.self) { index in
                        let column = index % columns
                        cell(
                            group: group, index: index, value: values[index],
                            edge: column == 0
                                ? .topLeading : column == columns - 1 ? .topTrailing : .top,
                            lit: hovered == group * 1000 + index)
                    }
                    // A short last row keeps the cells the same size.
                    ForEach(0..<(columns - row.count), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity, maxHeight: 22)
                    }
                }
            }
        }
    }

    private func cell(
        group: Int, index: Int, value: Double, edge: Alignment, lit: Bool
    )
        -> some View
    {
        let name = group == 0 ? "Performance" : "Efficiency"
        return RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(Self.fill(value, efficiency: group == 1))
            .overlay(
                Text("\(Int(value.rounded()))")
                    .font(.system(size: 10, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(.white.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(.white.opacity(lit ? 0.85 : 0), lineWidth: 1.5)
            )
            .frame(maxWidth: .infinity).frame(height: 22)
            .overlay(alignment: edge) {
                if lit {
                    MenuTooltip(text: "\(name) core \(index + 1) · \(Int(value.rounded()))%")
                        .fixedSize().offset(y: -24)
                }
            }
            .zIndex(lit ? 1 : 0)
            .onGeometryChange(for: CGRect.self) {
                $0.frame(in: .named(WidgetMenuView.space))
            } action: {
                frames[group * 1000 + index] = $0
            }
    }

    /// From the menu's grey towards blue or teal as the core gets busier.
    static func fill(_ value: Double, efficiency: Bool) -> Color {
        let full = efficiency ? MenuRGB(14, 124, 140) : MenuRGB(0, 96, 223)
        return MenuRGB(58, 58, 60).mixed(with: full, by: min(max(value, 0), 100) / 100).color
    }
}

/// Colours for a temperature: teal when cool, through amber at 80° to red at 95°.
enum MenuHeat {
    private static let stops: [(at: Double, rgb: MenuRGB)] = [
        (66, MenuRGB(64, 200, 224)), (73, MenuRGB(232, 197, 71)), (80, MenuRGB(255, 159, 10)),
        (95, MenuRGB(255, 69, 58))
    ]

    static func colour(_ value: Double) -> Color {
        guard let first = stops.first, let last = stops.last else { return .teal }
        if value <= first.at { return first.rgb.color }
        for (lower, upper) in zip(stops, stops.dropFirst()) where value <= upper.at {
            return lower.rgb.mixed(with: upper.rgb, by: (value - lower.at) / (upper.at - lower.at))
                .color
        }
        return last.rgb.color
    }

    /// Left to right, the colour of each moment, so a hot stretch shows
    /// where it happened.
    static func gradient(_ points: [Double]) -> LinearGradient {
        guard points.count > 1 else {
            return LinearGradient(
                colors: [colour(points.first ?? 0)], startPoint: .leading, endPoint: .trailing)
        }
        let count = 16
        let stops = (0..<count).map { step -> Gradient.Stop in
            let position = Double(step) * Double(points.count - 1) / Double(count - 1)
            let lower = Int(position)
            let upper = min(points.count - 1, lower + 1)
            let value = points[lower] + (points[upper] - points[lower]) * (position - Double(lower))
            return .init(color: colour(value), location: Double(step) / Double(count - 1))
        }
        return LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing)
    }
}

/// A colour as red, green and blue out of 255, for mixing between two.
struct MenuRGB {
    var red: Double
    var green: Double
    var blue: Double

    init(_ red: Double, _ green: Double, _ blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    func mixed(with other: MenuRGB, by fraction: Double) -> MenuRGB {
        MenuRGB(
            red + (other.red - red) * fraction, green + (other.green - green) * fraction,
            blue + (other.blue - blue) * fraction)
    }

    var color: Color { Color(red: red / 255, green: green / 255, blue: blue / 255) }
}

extension Color {
    /// `#rrggbb` or `#rrggbbaa`, or the accent when it is neither.
    init(hex: String) {
        let digits = hex.dropFirst()
        guard digits.count == 6 || digits.count == 8, let value = UInt64(digits, radix: 16) else {
            self = .accentColor
            return
        }
        let rgba = digits.count == 6 ? value << 8 | 0xff : value
        self.init(
            red: Double(rgba >> 24 & 0xff) / 255, green: Double(rgba >> 16 & 0xff) / 255,
            blue: Double(rgba >> 8 & 0xff) / 255, opacity: Double(rgba & 0xff) / 255)
    }
}
