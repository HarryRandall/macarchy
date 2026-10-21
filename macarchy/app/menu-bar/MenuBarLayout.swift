import AppKit
import Macarchy

/// Keep measured positions until an authored layout edit requires a new arrangement.
struct MenuBarLayout {
    var frames: [String: CGRect] = [:]
    var memberFrames: [String: CGRect] = [:]
    let screenWidth: CGFloat
    let notch: CGRect

    @MainActor
    init(bar: MenuBarModel) {
        let screen = NSScreen.main
        let left = screen?.auxiliaryTopLeftArea ?? .zero
        let right = screen?.auxiliaryTopRightArea ?? .zero
        let notch =
            right.minX > left.maxX && left.height > 0
            ? CGRect(x: left.maxX, y: 0, width: right.minX - left.maxX, height: left.height)
            : .zero
        self.init(
            items: bar.items, configuration: bar.draft, applied: bar.applied,
            screenWidth: max(screen?.frame.width ?? 1512, 1), notch: notch)
    }

    init(
        items snapshots: [SketchybarItem], configuration: BarConfiguration,
        applied: BarConfiguration, screenWidth: CGFloat, notch: CGRect = .zero
    ) {
        self.screenWidth = screenWidth
        self.notch = notch
        let items = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.id, $0) })
        let native = Dictionary(
            uniqueKeysWithValues: configuration.components.map { component in
                let rects = component.members.filter { !$0.hasPrefix("gap.") }
                    .compactMap { items[$0] }.filter { $0.isOnScreen && $0.frame.width > 0 }.map(
                        \.frame)
                return (component.id, rects.reduce(CGRect.null) { $0.union($1) })
            })
        if Self.sameLayout(configuration, applied)
            && !configuration.components.contains(where: \.hasBoxLayout)
        {
            for component in configuration.components where component.visible {
                guard let measured = native[component.id], !measured.isNull else { continue }
                var frame = measured
                if let width = component.boxWidth { frame.size.width = width }
                frames[component.id] = frame
                for id in component.members where !id.hasPrefix("gap.") {
                    if let item = items[id], item.isOnScreen { memberFrames[id] = item.frame }
                }
            }
            return
        }
        arrange(configuration, applied: applied, items: items, native: native)
    }

    /// Colours, names and current sensor values do not change the component layout.
    static func sameLayout(_ draft: BarConfiguration, _ applied: BarConfiguration) -> Bool {
        let keys = ["height", "position", "padding_left", "padding_right", "y_offset"]
        guard keys.allSatisfy({ draft.geometry[$0] == applied.geometry[$0] }),
            draft.components.map(\.id) == applied.components.map(\.id)
        else { return false }
        return zip(draft.components, applied.components).allSatisfy { lhs, rhs in
            lhs.side == rhs.side && lhs.visible == rhs.visible && lhs.members == rhs.members
                && lhs.boxWidth == rhs.boxWidth && lhs.hasBoxLayout == rhs.hasBoxLayout
                && draft.padding(for: lhs) == applied.padding(for: rhs)
                && draft.spacing(for: lhs) == applied.spacing(for: rhs)
                && Self.samePresentationLayout(lhs, rhs)
                && (!lhs.isCustom
                    || (lhs.text == rhs.text && lhs.icon == rhs.icon
                        && lhs.format == rhs.format && lhs.customWidth == rhs.customWidth))
        }
    }

    private static func samePresentationLayout(_ lhs: BarComponent, _ rhs: BarComponent) -> Bool {
        func geometry(_ component: BarComponent) -> [String: [String: String]] {
            component.presentation.reduce(into: [:]) { result, member in
                let values = member.value.filter { key, _ in
                    key.hasSuffix("width") || key.hasSuffix("align") || key == "icon"
                        || key.contains("font")
                        || key.contains("padding") || key.contains("y_offset")
                        || key.hasSuffix("drawing") || key == "background.image.scale"
                }
                if !values.isEmpty { result[member.key] = values }
            }
        }
        return geometry(lhs) == geometry(rhs)
    }

    private mutating func arrange(
        _ configuration: BarConfiguration, applied: BarConfiguration,
        items: [String: SketchybarItem], native: [String: CGRect]
    ) {
        let height = Double(configuration.geometry["height"] ?? "35") ?? 35
        let previous = Dictionary(uniqueKeysWithValues: applied.components.map { ($0.id, $0) })
        for side in ["left", "center", "right"] {
            let components = configuration.components.filter { $0.side == side && $0.visible }
            let widths = components.map { component -> CGFloat in
                if let width = component.boxWidth { return width }
                let measured = native[component.id] ?? .null
                if component.isCustom || measured.isNull {
                    return Self.customWidth(component) + configuration.padding(for: component) * 2
                }
                let oldPadding = previous[component.id].map { applied.padding(for: $0) } ?? 0
                let presented = component.members.filter { !$0.hasPrefix("gap.") }
                    .compactMap { items[$0] }.filter(\.isOnScreen)
                    .map { $0.presenting(component).frame }.reduce(CGRect.null) { $0.union($1) }
                let contentWidth = presented.isNull ? measured.width : presented.width
                return max(
                    1, contentWidth + (configuration.padding(for: component) - oldPadding))
            }
            let total = zip(components, widths).reduce(0.0) {
                $0 + $1.1 + configuration.spacing(for: $1.0)
            }
            var cursor =
                side == "right"
                ? screenWidth - (Double(configuration.geometry["padding_right"] ?? "10") ?? 10)
                    - total
                : side == "center"
                    ? (screenWidth - total) / 2
                    : Double(configuration.geometry["padding_left"] ?? "10") ?? 10
            for (index, component) in components.enumerated() {
                let original = native[component.id] ?? .null
                let oldPadding = previous[component.id].map { applied.padding(for: $0) } ?? 0
                frames[component.id] = CGRect(x: cursor, y: 0, width: widths[index], height: height)
                var memberCursor = 0.0
                for id in component.members where !id.hasPrefix("gap.") {
                    guard let originalItem = items[id], originalItem.isOnScreen else { continue }
                    let item = originalItem.presenting(component)
                    memberFrames[id] = CGRect(
                        x: component.hasBoxLayout
                            ? cursor + memberCursor
                            : cursor + configuration.padding(for: component) - oldPadding
                                + item.frame.minX
                                - (original.isNull ? item.frame.minX : original.minX),
                        y: item.frame.minY, width: item.frame.width, height: height)
                    memberCursor += item.width
                }
                cursor += widths[index] + configuration.spacing(for: component)
            }
        }
    }

    static func customWidth(_ component: BarComponent) -> CGFloat {
        if component.kind == "spacer" { return component.customWidth }
        let text = (component.rendered(component.text) as NSString).size(withAttributes: [
            .font: NSFont.systemFont(ofSize: 12)
        ]).width
        let icon = (component.icon as NSString).size(withAttributes: [
            .font: NSFont.systemFont(ofSize: 15)
        ]).width
        return max(text + icon + (component.text.isEmpty || component.icon.isEmpty ? 0 : 8), 20)
    }
}
