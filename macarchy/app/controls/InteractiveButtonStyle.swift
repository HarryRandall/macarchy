import SwiftUI

/// Shared feedback for navigation, cards and custom icon controls.
///
/// macOS fills on hover rather than outlining, so this draws a wash and
/// nothing else. The earlier version added a 16% stroke, which put a ring
/// around cards that already carried a selection ring of their own, at a
/// different radius.
struct InteractiveButtonStyle: ButtonStyle {
    /// Match this to the radius the label actually draws, or the wash will sit
    /// slightly proud of the card it belongs to.
    var cornerRadius: CGFloat = Metrics.radiusControl

    func makeBody(configuration: Configuration) -> some View {
        InteractiveLabel(configuration: configuration, cornerRadius: cornerRadius)
    }

    private struct InteractiveLabel: View {
        let configuration: Configuration
        let cornerRadius: CGFloat
        @Environment(\.isEnabled) private var enabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var hovering = false

        var body: some View {
            configuration.label
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.hoverFill)
                        .opacity(enabled && hovering ? 1 : 0)
                        .allowsHitTesting(false)
                }
                .opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.45)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: hovering)
                .onHover { hovering = $0 }
        }
    }
}

/// Feedback for the glyph buttons along the window's bar.
///
/// The filled wash `InteractiveButtonStyle` draws belongs on a row or a card,
/// where it reads as the shape of the thing being pointed at. On a bare glyph
/// in the bar it read as a box appearing out of nowhere, so these brighten the
/// glyph instead and draw nothing behind it.
struct BarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        BarLabel(configuration: configuration)
    }

    private struct BarLabel: View {
        let configuration: Configuration
        @Environment(\.isEnabled) private var enabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var hovering = false

        var body: some View {
            configuration.label
                .foregroundStyle(
                    enabled && (hovering || configuration.isPressed)
                        ? AnyShapeStyle(Color.primary) : AnyShapeStyle(.secondary)
                )
                .opacity(enabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
                .animation(reduceMotion ? nil : Motion.hover, value: hovering)
                .onHover { hovering = $0 }
        }
    }
}

struct SidebarToggle: View {
    @Binding var isVisible: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // The root view animates every part of the collapse on one curve.
        // Running a second curve from here meant the sidebar and the buttons
        // above it moved on different timings, which read as a jump.
        Button {
            // One animation, started here, so the sidebar, the corner box and
            // the pane beside them all move in the same transaction. Animating
            // from inside the sidebar only moved the sidebar's own contents:
            // the row above lays its children out before that animation is
            // seen, so the width itself snapped.
            withAnimation(reduceMotion ? nil : Motion.snappy) { isVisible.toggle() }
        } label: {
            Image(systemName: "sidebar.leading")
                .font(.system(size: 15, weight: .medium))
                .frame(width: 28, height: 26)
                .contentShape(RoundedRectangle(cornerRadius: Metrics.radiusSmall))
        }
        .buttonStyle(BarButtonStyle())
        // The ring the system draws around a focused button read as a box
        // sitting in the bar long after the click that put it there.
        .focusEffectDisabled()
        .hoverHelp("Show the section names", enabled: !isVisible, placement: .right)
        .accessibilityLabel(isVisible ? "Collapse sidebar" : "Expand sidebar")
        .keyboardShortcut("s", modifiers: [.command, .control])
    }
}
