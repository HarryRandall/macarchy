import AppKit
import SwiftUI

enum HoverHelpPlacement {
    /// Above the pointer, flipping below when there is no room.
    case above
    /// Beside the control, for a rail of icons where vertical space is tight.
    case right
}

/// Timings from the measured range for hover-revealed content: show after the
/// pointer has settled, hide after a short grace so crossing between two
/// neighbouring rows does not flicker.
private enum HoverHelpTiming {
    static let show = Duration.milliseconds(400)
    static let hide = Duration.milliseconds(120)
}

/// The coordinate space the host establishes, so a bubble can be placed
/// against the pointer rather than against the middle of its control.
private let hoverHelpSpace = "macarchy.hoverHelp"

private struct HoverHelpEntry {
    let text: String
    let anchor: Anchor<CGRect>
    let placement: HoverHelpPlacement
    /// Where the pointer was, or `nil` when focus rather than hover asked for
    /// this help and the control itself is the only sensible target.
    let pointer: CGPoint?
}

private struct HoverHelpPreference: PreferenceKey {
    static let defaultValue: [HoverHelpEntry] = []
    static func reduce(value: inout [HoverHelpEntry], nextValue: () -> [HoverHelpEntry]) {
        value.append(contentsOf: nextValue())
    }
}

/// Holds the pointer without publishing it.
///
/// `onContinuousHover` fires on every mouse move. Writing that into `@State`
/// invalidated the hovered view on each event, which made scrolling over a
/// page full of help targets visibly stutter. A reference box records the
/// location at no redraw cost; it is only read once, when a bubble appears.
@MainActor private final class PointerBox {
    var point: CGPoint?
}

private struct HoverHelpModifier: ViewModifier {
    let text: String
    let enabled: Bool
    let placement: HoverHelpPlacement
    @FocusState private var focused: Bool
    @State private var pointerBox = PointerBox()
    @State private var pointer: CGPoint?
    @State private var hovering = false
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .focused($focused)
            .onContinuousHover(coordinateSpace: .named(hoverHelpSpace)) { phase in
                guard enabled else { return }
                switch phase {
                case .active(let location):
                    pointerBox.point = location
                    // Only the first move of a hover changes published state.
                    if !hovering { hovering = true }
                case .ended:
                    if hovering { hovering = false }
                }
            }
            .onChange(of: enabled) { _, _ in
                hovering = false
                visible = false
            }
            .onReceive(
                NotificationCenter.default.publisher(for: NSMenu.didBeginTrackingNotification)
            ) { _ in
                // Native menus retain focus and do not reliably send hover exit.
                hovering = false
                focused = false
                visible = false
            }
            // Keyboard focus shows help at once: arriving by Tab is already a
            // deliberate act, so there is no intent left to confirm.
            .onChange(of: focused) { _, isFocused in
                if isFocused && enabled {
                    pointer = nil
                    visible = true
                } else if !hovering {
                    visible = false
                }
            }
            .task(id: hovering && enabled) {
                guard enabled else { return }
                guard hovering else {
                    guard !focused else { return }
                    try? await Task.sleep(for: HoverHelpTiming.hide)
                    guard !Task.isCancelled else { return }
                    visible = false
                    return
                }
                try? await Task.sleep(for: HoverHelpTiming.show)
                guard !Task.isCancelled else { return }
                pointer = pointerBox.point
                visible = true
            }
            .anchorPreference(key: HoverHelpPreference.self, value: .bounds) { anchor in
                visible && enabled
                    ? [
                        HoverHelpEntry(
                            text: text, anchor: anchor, placement: placement, pointer: pointer)
                    ]
                    : []
            }
            .accessibilityHint(enabled ? text : "")
    }
}

private struct HoverHelpBubble: View {
    let entry: HoverHelpEntry
    let source: CGRect
    let bounds: CGSize

    /// Constrain text before measuring its height so every wrapped line stays
    /// inside the bubble, including its padding.
    private static let maxWidth: CGFloat = 240
    private static let gap: CGFloat = 10
    private static let margin: CGFloat = 12

    @State private var size: CGSize = .zero

    private var textWidth: CGFloat {
        let available = max(
            1, min(Self.maxWidth, bounds.width - Self.margin * 2) - Metrics.medium * 2)
        let natural =
            entry.text.components(separatedBy: "\n").map {
                ($0 as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 12)]).width
            }.max() ?? 0
        return min(available, max(1, ceil(natural)))
    }

    var body: some View {
        Text(entry.text)
            .font(.system(size: 12))
            .foregroundStyle(.primary)
            .multilineTextAlignment(.leading)
            .frame(width: textWidth, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Metrics.medium)
            .padding(.vertical, Metrics.small + 1)
            .onGeometryChange(for: CGSize.self) {
                $0.size
            } action: {
                size = $0
            }
            .glassEffect(.regular, in: shape)
            .overlay(shape.strokeBorder(Color.cardBorder, lineWidth: 1))
            .shadow(color: .black.opacity(0.22), radius: 10, y: 3)
            // The first pass has no measurement yet, so the bubble would be
            // placed with a guessed size and then jump. Stay invisible for
            // that one frame instead.
            .opacity(size == .zero ? 0 : 1)
            .offset(x: origin.x, y: origin.y)
            .allowsHitTesting(false)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.radiusControl, style: .continuous)
    }

    private var placesAbove: Bool {
        source.minY - Self.gap - size.height >= Self.margin
    }

    private var origin: CGPoint {
        let inset = Self.gap
        let x: CGFloat
        let y: CGFloat
        switch entry.placement {
        case .above:
            x = (entry.pointer?.x ?? source.midX) - size.width / 2
            y = placesAbove ? source.minY - inset - size.height : source.maxY + inset
        case .right:
            x = source.maxX + inset
            y = source.midY - size.height / 2
        }
        return CGPoint(
            x: min(max(Self.margin, x), max(Self.margin, bounds.width - size.width - Self.margin)),
            y: min(max(Self.margin, y), max(Self.margin, bounds.height - size.height - Self.margin))
        )
    }
}

extension View {
    func hoverHelp(
        _ text: String, enabled: Bool = true, placement: HoverHelpPlacement = .above
    ) -> some View {
        modifier(HoverHelpModifier(text: text, enabled: enabled, placement: placement))
    }

    /// Render above scrolling content so help never gets cut off by a card or
    /// viewport, and establish the space bubbles are positioned in.
    func hoverHelpHost() -> some View {
        coordinateSpace(.named(hoverHelpSpace))
            .overlayPreferenceValue(HoverHelpPreference.self) { entries in
                GeometryReader { geometry in
                    if let entry = entries.last {
                        HoverHelpBubble(
                            entry: entry, source: geometry[entry.anchor], bounds: geometry.size
                        )
                        .transition(
                            .opacity.combined(with: .scale(scale: 0.94, anchor: .bottom)))
                    }
                }
                .allowsHitTesting(false)
                .motion(Motion.hover, value: entries.last?.text)
            }
    }
}
