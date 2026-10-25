import Macarchy
import SwiftUI

/// Two readings over the same minute on one card, the first rising above a
/// centre line and the second falling below it, as download over upload.
/// Each half names itself and its reading at the edge its line is drawn
/// towards. Pointing at it marks the moment and gives both values.
struct MenuMirror: View {
    let item: WidgetMenuItem
    let pointer: CGPoint?
    @State private var frame: CGRect = .zero
    private let height: CGFloat = 64

    private var halves: [[Double]] { MenuValues.groups(item.value) }
    private var labels: [String] { Self.parts(item.label) }
    private var currents: [String] { Self.parts(item.current) }
    private var colours: [Color] {
        let given = Self.parts(item.colour)
        return [0, 1].map { index in
            let colour = given.indices.contains(index) ? given[index] : ""
            if colour.hasPrefix("#") { return Color(hex: colour) }
            return index == 0 || colour == "accent" ? .accentColor : Color(hex: "#ff9f0a")
        }
    }

    static func parts(_ text: String) -> [String] {
        text.split(separator: "|", omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
    }

    private var count: Int { halves.map(\.count).max() ?? 0 }

    private var hovered: Int? {
        guard let pointer, frame.contains(pointer), count > 1 else { return nil }
        let fraction = (pointer.x - frame.minX) / max(frame.width, 1)
        return min(max(Int((fraction * Double(count - 1)).rounded()), 0), count - 1)
    }

    var body: some View {
        let halves = self.halves
        let colours = self.colours
        let hovered = self.hovered
        VStack(spacing: 4) {
            edge(0, colour: colours[0]).padding(.top, 8)
            GeometryReader { geometry in
                graph(halves, colours: colours, size: geometry.size, hovered: hovered)
            }
            .frame(height: height)
            .onGeometryChange(for: CGRect.self) {
                $0.frame(in: .named(WidgetMenuView.space))
            } action: {
                frame = $0
            }
            edge(1, colour: colours[1]).padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .background(.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.horizontal, 10).padding(.vertical, 2)
    }

    private func edge(_ index: Int, colour: Color) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(labels.indices.contains(index) ? labels[index] : "")
                .font(.system(size: 11, weight: .medium)).foregroundStyle(colour).lineLimit(1)
            Spacer(minLength: 4)
            Text(currents.indices.contains(index) ? currents[index] : "")
                .font(.system(size: 16, weight: .semibold)).monospacedDigit().lineLimit(1)
        }
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private func graph(
        _ halves: [[Double]], colours: [Color], size: CGSize, hovered: Int?
    ) -> some View {
        let middle = size.height / 2
        let top = halves.max { ($0.max() ?? 0) < ($1.max() ?? 0) }?.max() ?? 0
        let scale = max(top, 1)
        ZStack(alignment: .topLeading) {
            ForEach(Array(halves.prefix(2).enumerated()), id: \.offset) { index, points in
                let spots = Self.spots(points, size: size, scale: scale, down: index == 1)
                let line = MenuSpark.line(spots)
                Self.area(spots, line: line, middle: middle)
                    .fill(
                        LinearGradient(
                            colors: [colours[index].opacity(0.03), colours[index].opacity(0.4)],
                            startPoint: index == 0 ? .bottom : .top,
                            endPoint: index == 0 ? .top : .bottom))
                line.stroke(
                    colours[index],
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
            Path { path in
                path.move(to: CGPoint(x: 0, y: middle))
                path.addLine(to: CGPoint(x: size.width, y: middle))
            }
            .stroke(.white.opacity(0.18), lineWidth: 1)
            if let hovered {
                marker(halves, at: hovered, size: size, scale: scale)
            }
        }
    }

    @ViewBuilder
    private func marker(
        _ halves: [[Double]], at index: Int, size: CGSize, scale: Double
    )
        -> some View
    {
        let x = CGFloat(index) * size.width / CGFloat(max(count - 1, 1))
        Path { path in
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
        }
        .stroke(.white.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
        let values = halves.prefix(2).map { $0.indices.contains(index) ? $0[index] : 0 }
        let steps = count - 1 - index
        let when = steps == 0 ? "now" : "\(Int(Double(steps) * item.interval))s ago"
        let text =
            values.map { MenuValues.format($0, unit: item.unit) }.joined(separator: " · ")
            + " · \(when)"
        let width = CGFloat(text.count) * 5.6 + 12
        MenuTooltip(text: text)
            .fixedSize()
            .position(x: min(max(x, width / 2 + 2), size.width - width / 2 - 2), y: size.height / 2)
    }

    /// Points rising from the centre of `size`, or falling from it when
    /// `down`, to just short of the edge at `scale`.
    static func spots(_ points: [Double], size: CGSize, scale: Double, down: Bool) -> [CGPoint] {
        guard points.count > 1 else { return [] }
        let middle = size.height / 2
        return points.enumerated().map { index, value in
            let offset = CGFloat(min(max(value, 0), scale) / scale) * (middle - 3)
            return CGPoint(
                x: CGFloat(index) * size.width / CGFloat(points.count - 1),
                y: down ? middle + 1 + offset : middle - 1 - offset)
        }
    }

    /// The area between a line and the centre.
    static func area(_ spots: [CGPoint], line: Path, middle: CGFloat) -> Path {
        var path = line
        guard let first = spots.first, let last = spots.last else { return path }
        path.addLine(to: CGPoint(x: last.x, y: middle))
        path.addLine(to: CGPoint(x: first.x, y: middle))
        path.closeSubpath()
        return path
    }
}
