import Macarchy
import SwiftUI

/// Graphs drawn as cards, two to a row, such as CPU load beside its
/// temperature: the reading large in the corner and the last minute filling
/// the card edge to edge. Pointing at one marks the moment under the pointer,
/// says what it was and when, and shows the minute's peak.
struct MenuCards: View {
    let items: [WidgetMenuItem]
    let pointer: CGPoint?

    var body: some View {
        HStack(spacing: 8) {
            ForEach(items) { MenuCard(item: $0, pointer: pointer) }
        }
        .padding(.horizontal, 10).padding(.vertical, 2)
    }
}

struct MenuCard: View {
    let item: WidgetMenuItem
    let pointer: CGPoint?
    @State private var frame: CGRect = .zero
    private let height: CGFloat = 46

    private var points: [Double] { MenuValues.numbers(item.value) }
    private var degrees: Bool { item.unit == "°" }
    /// `%` runs 0 to 100 and `°` 40° to 100°, unless the row sets a scale;
    /// other units reach just past the largest point.
    private var range: ClosedRange<Double> {
        let fallback: ClosedRange<Double> =
            item.unit == "%" ? 0...100 : degrees ? 40...100 : 0...max((points.max() ?? 0) * 1.15, 1)
        let lower = item.min ?? fallback.lowerBound
        return lower...Swift.max(item.max ?? fallback.upperBound, lower + 1)
    }

    private var hovered: Int? {
        guard let pointer, frame.contains(pointer), points.count > 1 else { return nil }
        let fraction = (pointer.x - frame.minX) / max(frame.width, 1)
        return min(max(Int((fraction * Double(points.count - 1)).rounded()), 0), points.count - 1)
    }

    var body: some View {
        let points = self.points
        let hovered = self.hovered
        let peak = points.max() ?? 0
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(hovered == nil ? item.label : "Peak \(format(peak))")
                    .font(.system(size: 11)).lineLimit(1)
                    .foregroundStyle(
                        hovered != nil && degrees && peak >= 80
                            ? AnyShapeStyle(MenuHeat.colour(peak)) : AnyShapeStyle(.secondary))
                Spacer(minLength: 4)
                Text(item.current)
                    .font(.system(size: 16, weight: .semibold)).monospacedDigit().lineLimit(1)
                    .foregroundStyle(currentStyle)
            }
            .padding(.horizontal, 8).padding(.top, 8)
            GeometryReader { geometry in
                graph(points, size: geometry.size, hovered: hovered, peak: peak)
            }
            .frame(height: height)
        }
        .frame(maxWidth: .infinity)
        .background(.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onGeometryChange(for: CGRect.self) {
            $0.frame(in: .named(WidgetMenuView.space))
        } action: {
            frame = $0
        }
    }

    private var currentStyle: AnyShapeStyle {
        guard degrees, let value = MenuValues.numbers(item.current).first else {
            return AnyShapeStyle(.primary)
        }
        return AnyShapeStyle(MenuHeat.colour(value))
    }

    @ViewBuilder
    private func graph(_ points: [Double], size: CGSize, hovered: Int?, peak: Double) -> some View {
        let spots = spots(points, size: size)
        let line = MenuSpark.line(spots)
        let area = MenuSpark.area(spots, size: size)
        ZStack(alignment: .topLeading) {
            if item.colour == "temperature" {
                let heat = MenuHeat.gradient(points)
                area.fill(heat)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.62), location: 0),
                                .init(color: .white.opacity(0.18), location: 0.55),
                                .init(color: .white.opacity(0.02), location: 1)
                            ], startPoint: .top, endPoint: .bottom))
                line.stroke(
                    heat, style: StrokeStyle(lineWidth: 1.75, lineCap: .round, lineJoin: .round))
            } else {
                let colour =
                    item.colour.hasPrefix("#") ? Color(hex: item.colour) : Color.accentColor
                area.fill(
                    LinearGradient(
                        colors: [colour.opacity(0.34), colour.opacity(0.03)], startPoint: .top,
                        endPoint: .bottom))
                line.stroke(
                    colour, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
            if let hovered, spots.indices.contains(hovered) {
                marker(
                    at: spots[hovered], value: points[hovered], index: hovered, size: size,
                    peak: peak)
            }
        }
    }

    @ViewBuilder
    private func marker(
        at spot: CGPoint, value: Double, index: Int, size: CGSize, peak: Double
    )
        -> some View
    {
        let peakY = y(peak, height: size.height)
        Path { path in
            path.move(to: CGPoint(x: 0, y: peakY))
            path.addLine(to: CGPoint(x: size.width, y: peakY))
        }
        .stroke(.white.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
        Path { path in
            path.move(to: CGPoint(x: spot.x, y: 0))
            path.addLine(to: CGPoint(x: spot.x, y: size.height))
        }
        .stroke(.white.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
        Circle()
            .fill(item.colour == "temperature" ? MenuHeat.colour(value) : Color.accentColor)
            .overlay(Circle().stroke(.white, lineWidth: 1.25))
            .frame(width: 6, height: 6)
            .position(spot)
        let text = "\(format(value)) · \(ago(index))"
        let width = CGFloat(text.count) * 5.6 + 12
        let x = min(max(spot.x, width / 2 + 2), size.width - width / 2 - 2)
        MenuTooltip(text: text)
            .fixedSize()
            .position(x: x, y: spot.y - 20 >= 1 ? spot.y - 13 : spot.y + 14)
    }

    private func spots(_ points: [Double], size: CGSize) -> [CGPoint] {
        guard points.count > 1 else { return [] }
        return points.enumerated().map { index, value in
            CGPoint(
                x: CGFloat(index) * size.width / CGFloat(points.count - 1),
                y: y(value, height: size.height))
        }
    }

    private func y(_ value: Double, height: CGFloat) -> CGFloat {
        let fraction =
            (min(max(value, range.lowerBound), range.upperBound) - range.lowerBound)
            / (range.upperBound - range.lowerBound)
        return 4 + (1 - fraction) * (height - 5)
    }

    private func format(_ value: Double) -> String {
        MenuValues.format(value, unit: item.unit)
    }

    private func ago(_ index: Int) -> String {
        let steps = points.count - 1 - index
        return steps == 0 ? "now" : "\(Int(Double(steps) * item.interval))s ago"
    }
}

/// A smooth line through points, and the area under it to the bottom edge.
enum MenuSpark {
    static func line(_ spots: [CGPoint]) -> Path {
        Path { path in
            guard let first = spots.first else { return }
            path.move(to: first)
            for index in 0..<max(spots.count - 1, 0) {
                let before = spots[max(0, index - 1)]
                let start = spots[index]
                let end = spots[index + 1]
                let after = spots[min(spots.count - 1, index + 2)]
                path.addCurve(
                    to: end,
                    control1: CGPoint(
                        x: start.x + (end.x - before.x) / 6, y: start.y + (end.y - before.y) / 6),
                    control2: CGPoint(
                        x: end.x - (after.x - start.x) / 6, y: end.y - (after.y - start.y) / 6))
            }
        }
    }

    static func area(_ spots: [CGPoint], size: CGSize) -> Path {
        var path = line(spots)
        guard let first = spots.first, let last = spots.last else { return path }
        path.addLine(to: CGPoint(x: last.x + 1, y: last.y))
        path.addLine(to: CGPoint(x: last.x + 1, y: size.height + 1))
        path.addLine(to: CGPoint(x: first.x - 1, y: size.height + 1))
        path.addLine(to: CGPoint(x: first.x - 1, y: first.y))
        path.closeSubpath()
        return path
    }
}
