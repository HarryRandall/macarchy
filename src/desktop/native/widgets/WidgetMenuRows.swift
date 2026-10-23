import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers

/// How the richer dropdown rows read their value, which a provider writes
/// as text: numbers for a graph, groups of numbers for cores, and
/// `Name:value` pairs for apps.
enum MenuValues {
    /// Numbers separated by commas or spaces, such as `12,30,45`.
    static func numbers(_ text: String) -> [Double] {
        text.split(whereSeparator: { $0 == "," || $0.isWhitespace }).compactMap {
            Double($0.trimmingCharacters(in: CharacterSet(charactersIn: "%°")))
        }
    }

    /// Groups of numbers separated by `|`: performance cores, then efficiency cores.
    static func groups(_ text: String) -> [[Double]] {
        text.split(separator: "|").map { numbers(String($0)) }.filter { !$0.isEmpty }
    }

    /// `Name:value` pairs separated by commas. The value is optional.
    static func apps(_ text: String) -> [(name: String, value: String)] {
        text.split(separator: ",").compactMap { pair in
            let parts = pair.split(separator: ":", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            guard let name = parts.first, !name.isEmpty else { return nil }
            return (name, parts.count > 1 ? parts[1] : "")
        }
    }
}

/// A reading over time, such as the last minute of CPU load, out of 100.
/// Pointing at it marks the nearest sample and shows its value.
struct MenuGraph: View {
    let caption: String
    let points: [Double]
    let pointer: CGPoint?
    @State private var frame: CGRect = .zero

    private var hovered: Int? {
        guard let pointer, frame.contains(pointer), points.count > 1 else { return nil }
        let fraction = (pointer.x - frame.minX) / max(frame.width, 1)
        return min(max(Int((fraction * Double(points.count - 1)).rounded()), 0), points.count - 1)
    }

    var body: some View {
        let hovered = self.hovered
        VStack(alignment: .leading, spacing: 3) {
            Chart {
                ForEach(Array(points.enumerated()), id: \.offset) { point in
                    AreaMark(x: .value("Time", point.offset), y: .value("Value", point.element))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.accentColor.opacity(0.35), Color.accentColor.opacity(0.02)
                                ],
                                startPoint: .top, endPoint: .bottom)
                        )
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("Time", point.offset), y: .value("Value", point.element))
                        .foregroundStyle(Color.accentColor)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                        .interpolationMethod(.monotone)
                }
                if let hovered {
                    RuleMark(x: .value("Time", hovered))
                        .foregroundStyle(Color.secondary.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
                    PointMark(x: .value("Time", hovered), y: .value("Value", points[hovered]))
                        .foregroundStyle(Color.accentColor)
                        .symbolSize(36)
                        .annotation(
                            position: .top, spacing: 4,
                            overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))
                        ) {
                            MenuTooltip(text: Self.format(points[hovered]))
                        }
                }
            }
            .chartXScale(domain: 0...max(points.count - 1, 1))
            .chartYScale(domain: 0...max(100, points.max() ?? 0))
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 54)
            .onGeometryChange(for: CGRect.self) {
                $0.frame(in: .named(WidgetMenuView.space))
            } action: {
                frame = $0
            }
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 8).fill(.primary.opacity(0.05)))
            HStack {
                Text(caption.isEmpty ? "Last minute" : caption)
                Spacer()
                Text(hovered == nil || hovered == points.count - 1 ? "Now" : "Earlier")
            }
            .font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 2)
    }

    static func format(_ value: Double) -> String {
        value.rounded() == value ? "\(Int(value))%" : String(format: "%.1f%%", value)
    }
}

/// Use per core, as bars: performance cores, then efficiency cores.
/// Pointing at a bar names the core and its use.
struct MenuCores: View {
    let groups: [[Double]]
    let pointer: CGPoint?
    private let height: CGFloat = 30
    @State private var frames: [Int: CGRect] = [:]

    /// The bar under the pointer, as group and position.
    private var hovered: (group: Int, index: Int)? {
        guard let pointer,
            let key = frames.first(where: { $0.value.insetBy(dx: -1.5, dy: 0).contains(pointer) })?
                .key
        else { return nil }
        return (key / 1000, key % 1000)
    }

    var body: some View {
        let hovered = self.hovered
        VStack(spacing: 3) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(groups.enumerated()), id: \.offset) { group, values in
                    ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                        let lit = hovered.map { $0 == (group, index) } ?? false
                        RoundedRectangle(cornerRadius: 2)
                            .fill(group == 0 ? Color.accentColor : Color.teal)
                            .brightness(lit ? 0.15 : 0)
                            .opacity(hovered == nil || lit ? 1 : 0.55)
                            .frame(height: max(2, height * min(value, 100) / 100))
                            .frame(maxWidth: .infinity, maxHeight: height, alignment: .bottom)
                            .onGeometryChange(for: CGRect.self) {
                                $0.frame(in: .named(WidgetMenuView.space))
                            } action: {
                                frames[group * 1000 + index] = $0
                            }
                    }
                    if group < groups.count - 1 { Spacer().frame(width: 6) }
                }
            }
            .frame(height: height, alignment: .bottom)
            HStack {
                if let hovered, groups.indices.contains(hovered.group),
                    groups[hovered.group].indices.contains(hovered.index)
                {
                    Text(
                        "\(hovered.group == 0 ? "Performance" : "Efficiency") core \(hovered.index + 1)"
                    )
                    Spacer()
                    Text(MenuGraph.format(groups[hovered.group][hovered.index])).monospacedDigit()
                } else if groups.count > 1 {
                    Text("Performance")
                    Spacer()
                    Text("Efficiency")
                }
            }
            .font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 2)
    }
}

/// A small dark label for a value under the pointer.
struct MenuTooltip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold)).monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color.black.opacity(0.8)))
    }
}

/// Apps with their icons, such as the ones using the most CPU.
struct MenuApps: View {
    let apps: [(name: String, value: String)]

    var body: some View {
        ForEach(Array(apps.enumerated()), id: \.offset) { _, app in
            HStack(spacing: 8) {
                Image(nsImage: AppIcons.icon(named: app.name))
                    .resizable().frame(width: 18, height: 18)
                Text(app.name).lineLimit(1)
                Spacer(minLength: 12)
                Text(app.value).foregroundStyle(.secondary).monospacedDigit()
            }
            .padding(.horizontal, 10).frame(height: 26)
        }
    }
}

/// App icons by name: a running app's, or one found in the usual folders,
/// or the plain icon for a program with no app around it.
@MainActor
enum AppIcons {
    private static var cache: [String: NSImage] = [:]

    static func icon(named name: String) -> NSImage {
        if let icon = cache[name] { return icon }
        // Process names from ps are often lower case, or the program's own name.
        let running = NSWorkspace.shared.runningApplications.first {
            $0.localizedName?.caseInsensitiveCompare(name) == .orderedSame
                || $0.executableURL?.lastPathComponent == name
        }
        let folders = [
            "/Applications", "/System/Applications", "/System/Applications/Utilities",
            NSHomeDirectory() + "/Applications"
        ]
        let path = folders.map { "\($0)/\(name).app" }.first {
            FileManager.default.fileExists(atPath: $0)
        }
        let icon =
            running?.icon ?? path.map { NSWorkspace.shared.icon(forFile: $0) }
            ?? NSWorkspace.shared.icon(for: .unixExecutable)
        cache[name] = icon
        return icon
    }
}
