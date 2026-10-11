import SwiftUI

/// Every tile is the same height, whatever it carries.
///
/// The grid aligns rows to the top, so one taller tile used to shunt its
/// neighbours out of line. Fixing the height — and reserving a band for the
/// detail strip — keeps a row of tiles reading as a row.
enum StatTileMetrics {
    static let height: CGFloat = 96
    static let detail: CGFloat = 26
}

/// One number, said plainly, with room for a trend underneath.
///
/// A row of these replaces the ring-and-bar-chart pair that took a full band
/// of the Advanced page to report two facts.
struct StatTile<Detail: View>: View {
    let symbol: String
    let value: String
    let caption: String
    var tint: Color = .accentColor
    var emphasis = false
    @ViewBuilder var detail: Detail

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Metrics.small) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 18, height: 18)
                    .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 5))
                Text(caption)
                    .font(.meta)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }

            Spacer(minLength: Metrics.xs)

            // A theme name or a relative date has to survive a narrow column,
            // so the value shrinks rather than wrapping or clipping.
            Text(value)
                .font(emphasis ? .heroTitle : .sectionTitle)
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .motion(Motion.snappy, value: value)

            Spacer(minLength: Metrics.xs)

            detail
                .frame(
                    maxWidth: .infinity, minHeight: StatTileMetrics.detail,
                    alignment: .bottomLeading)
        }
        .padding(Metrics.medium)
        .frame(maxWidth: .infinity, minHeight: StatTileMetrics.height, alignment: .topLeading)
        .background(Color.cardSurface, in: shape)
        .overlay(shape.strokeBorder(Color.cardBorder, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(caption): \(value)")
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.radiusCard, style: .continuous)
    }
}

extension StatTile where Detail == EmptyView {
    init(
        symbol: String, value: String, caption: String, tint: Color = .accentColor,
        emphasis: Bool = false
    ) {
        self.init(
            symbol: symbol, value: value, caption: caption, tint: tint, emphasis: emphasis,
            detail: { EmptyView() })
    }
}

/// A trend line small enough to sit inside a tile.
///
/// Draws nothing but the shape of the data — no axes, no grid, no legend. A
/// seven-point series does not need a chart framework, and the bar chart that
/// used to show it rendered one bar and six empty columns.
struct Sparkline: View {
    let values: [Double]
    var tint: Color = .accentColor
    var height: CGFloat = 22
    var filled = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0

    private var normalised: [Double] {
        guard let low = values.min(), let high = values.max(), high > low else {
            return values.map { _ in 0.5 }
        }
        return values.map { ($0 - low) / (high - low) }
    }

    var body: some View {
        GeometryReader { geometry in
            let points = points(in: geometry.size)
            ZStack {
                if filled {
                    area(points, in: geometry.size)
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.28), tint.opacity(0.02)],
                                startPoint: .top, endPoint: .bottom))
                }
                line(points)
                    .trim(from: 0, to: progress)
                    .stroke(
                        tint,
                        style: StrokeStyle(
                            lineWidth: 1.5, lineCap: .round,
                            lineJoin: .round))
                if let last = points.last {
                    Circle()
                        .fill(tint)
                        .frame(width: 4, height: 4)
                        .position(last)
                        .opacity(progress >= 1 ? 1 : 0)
                }
            }
        }
        .frame(height: height)
        .task {
            guard !reduceMotion else {
                progress = 1
                return
            }
            withAnimation(.easeOut(duration: 0.55)) { progress = 1 }
        }
        .accessibilityHidden(true)
    }

    private func points(in size: CGSize) -> [CGPoint] {
        let series = normalised
        guard series.count > 1 else {
            return [CGPoint(x: size.width / 2, y: size.height / 2)]
        }
        let step = size.width / CGFloat(series.count - 1)
        return series.enumerated().map { index, value in
            CGPoint(
                x: CGFloat(index) * step,
                y: size.height - (CGFloat(value) * (size.height - 3)) - 1.5)
        }
    }

    private func line(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        return path
    }

    private func area(_ points: [CGPoint], in size: CGSize) -> Path {
        var path = line(points)
        guard let first = points.first, let last = points.last else { return path }
        path.addLine(to: CGPoint(x: last.x, y: size.height))
        path.addLine(to: CGPoint(x: first.x, y: size.height))
        path.closeSubpath()
        return path
    }
}

/// A row of proportional bars, for a small categorical breakdown.
///
/// Each column is given the same width and drawn on a track, so an empty
/// category still occupies its slot instead of collapsing to a sliver and
/// leaving the row looking broken.
struct MiniBars: View {
    struct Bar: Identifiable {
        let id: String
        let label: String
        let value: Int
        init(_ label: String, _ value: Int) {
            self.id = label
            self.label = label
            self.value = value
        }
    }

    let bars: [Bar]
    var tint: Color = .accentColor
    var trackHeight: CGFloat = 20

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grown = false

    private var peak: Int { max(1, bars.map(\.value).max() ?? 1) }

    var body: some View {
        HStack(alignment: .bottom, spacing: Metrics.xs) {
            ForEach(bars) { bar in
                VStack(spacing: 3) {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(Color.controlWell)
                            .frame(height: trackHeight)
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(bar.value == 0 ? Color.clear : tint.opacity(0.85))
                            .frame(
                                height: grown
                                    ? trackHeight * CGFloat(bar.value) / CGFloat(peak) : 0)
                    }
                    Text(bar.label)
                        .font(.badge)
                        .foregroundStyle(Color.metaText)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .hoverHelp("\(bar.value) use \(bar.label)")
            }
        }
        .frame(maxWidth: .infinity)
        .task {
            guard !reduceMotion else {
                grown = true
                return
            }
            withAnimation(Motion.smooth) { grown = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(bars.map { "\($0.label) \($0.value)" }.joined(separator: ", "))
    }
}
