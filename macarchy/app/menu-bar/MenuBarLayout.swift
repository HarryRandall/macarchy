import AppKit
import Macarchy

/// Keep measured positions until layout edits require a new arrangement.
struct MenuBarLayout {
    var frames: [String: CGRect] = [:]
    var memberFrames: [String: CGRect] = [:]
    let screenWidth: CGFloat
    let notch: CGRect

    @MainActor
    init(bar: MenuBarModel) {
        let screen = NSScreen.main
        screenWidth = max(screen?.frame.width ?? 1512, 1)
        let left = screen?.auxiliaryTopLeftArea ?? .zero
        let right = screen?.auxiliaryTopRightArea ?? .zero
        notch =
            right.minX > left.maxX && left.height > 0
            ? CGRect(x: left.maxX, y: 0, width: right.minX - left.maxX, height: left.height) : .zero
        let items = Dictionary(uniqueKeysWithValues: bar.items.map { ($0.id, $0) })
        var native: [String: CGRect] = [:]
        for component in bar.draft.components {
            let rects = component.members.filter { !$0.hasPrefix("gap.") }.compactMap { items[$0] }
                .filter {
                    $0.frame.width > 0 && $0.frame.minX > -1000
                        && ($0.drawing || !component.visible)
                }
                .map(\.frame)
            native[component.id] = rects.reduce(CGRect.null) { $0.union($1) }
        }
        for side in ["left", "center", "right"] {
            let components = bar.draft.components.filter { $0.side == side && $0.visible }
            let widths = components.map { component -> CGFloat in
                let measured = native[component.id] ?? .null
                let content =
                    component.isCustom
                    ? Self.customWidth(component)
                    : max(measured.isNull ? 50 : measured.width, 1)
                return content + bar.draft.padding(for: component) * 2
                    + bar.draft.spacing(for: component)
            }
            let total = widths.reduce(0, +)
            var cursor =
                side == "right"
                ? screenWidth - (Double(bar.draft.geometry["padding_right"] ?? "10") ?? 10) - total
                : side == "center"
                    ? (screenWidth - total) / 2
                    : Double(bar.draft.geometry["padding_left"] ?? "10") ?? 10
            for (index, component) in components.enumerated() {
                let original = native[component.id] ?? .null
                let x = cursor
                let frame = CGRect(x: x, y: 0, width: max(widths[index], 1), height: bar.height)
                frames[component.id] = frame
                for id in component.members {
                    guard !id.hasPrefix("gap."), let item = items[id], item.drawing, item.isOnScreen
                    else { continue }
                    memberFrames[id] = CGRect(
                        x: x + bar.draft.padding(for: component) + item.frame.minX
                            - (original.isNull ? item.frame.minX : original.minX),
                        y: item.frame.minY, width: item.frame.width, height: bar.height)
                }
                cursor += widths[index]
            }
        }
    }

    static func customWidth(_ component: BarComponent) -> CGFloat {
        if component.kind == "spacer" { return component.customWidth }
        let text = (component.text as NSString).size(withAttributes: [
            .font: NSFont.systemFont(ofSize: 12)
        ]).width
        let icon = (component.icon as NSString).size(withAttributes: [
            .font: NSFont.systemFont(ofSize: 15)
        ]).width
        return max(
            text + icon + (component.text.isEmpty || component.icon.isEmpty ? 0 : 8), 20)
    }
}
