import SwiftUI

/// A state, said in one glance: a dot, a word, one colour.
struct StatusChip: View {
    enum Tone {
        case good, warning, bad, idle

        var colour: Color {
            switch self {
            case .good: .green
            case .warning: .orange
            case .bad: .red
            case .idle: .secondary
            }
        }
    }

    let tone: Tone
    let label: String
    /// A running service gets a soft pulse so the page has a pulse of its own.
    var live = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Metrics.xs + 2) {
            // The pulse is an overlay on the dot rather than a second view
            // stacked beside it: laid out as a sibling, it came adrift of the
            // dot when the chip was re-laid out and rang out over the label.
            Circle()
                .fill(tone.colour)
                .frame(width: 6, height: 6)
                .overlay {
                    if live && !reduceMotion {
                        Circle()
                            .fill(tone.colour)
                            .phaseAnimator([0.6, 1.0]) { view, phase in
                                view.scaleEffect(phase * 2.2).opacity(1.6 - phase * 1.5)
                            } animation: { _ in
                                .easeOut(duration: 1.6).repeatForever(autoreverses: false)
                            }
                            .allowsHitTesting(false)
                    }
                }
                .frame(width: 8, height: 8)

            Text(label)
                .font(.meta)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, Metrics.small)
        .padding(.vertical, 3)
        .background(Color.controlWell, in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }
}

/// Health as a strip of segments rather than a ring.
///
/// A ring reports one ratio and needs a caption to say what the parts are.
/// One segment per service says which one is down without being asked.
struct HealthStrip: View {
    struct Segment: Identifiable {
        let id: String
        let label: String
        let ok: Bool
    }

    let segments: [Segment]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 3) {
            ForEach(segments) { segment in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(segment.ok ? Color.green.opacity(0.85) : Color.orange.opacity(0.85))
                    .frame(height: 5)
                    .hoverHelp(
                        segment.ok
                            ? "\(segment.label) is running" : "\(segment.label) is not running")
            }
        }
        .motion(Motion.snappy, value: segments.map(\.ok))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(segments.filter(\.ok).count) of \(segments.count) services running")
    }
}

/// A square, quiet button carrying one glyph.
///
/// Four rows of `Restart` and `Stop` text buttons took the accent colour and
/// turned a settings card into a wall of tinted pills.
struct IconButton: View {
    let symbol: String
    let help: String
    var tone: Color = .secondary
    var isBusy = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isBusy {
                    ProgressView().controlSize(.small).scaleEffect(0.7)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(tone)
                }
            }
            .frame(width: 26, height: 24)
            .contentShape(RoundedRectangle(cornerRadius: Metrics.radiusSmall))
        }
        .buttonStyle(InteractiveButtonStyle(cornerRadius: Metrics.radiusSmall))
        .disabled(isBusy)
        .hoverHelp(help)
        .accessibilityLabel(help)
    }
}

/// A group of icon buttons sharing one well, so a row of actions reads as one
/// control rather than several competing pills.
struct ActionCluster<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 1) {
            content
        }
        .padding(2)
        .background(Color.controlWell, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.cardBorder, lineWidth: 1))
    }
}

/// A count in a soft pill, for a filter or a tab.
struct CountBadge: View {
    let count: Int
    var tint: Color?

    var body: some View {
        Text("\(count)")
            .font(.badge)
            .monospacedDigit()
            .contentTransition(.numericText())
            .foregroundStyle(tint ?? Color.metaText)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background((tint ?? Color.primary).opacity(0.12), in: Capsule())
            .motion(Motion.snappy, value: count)
    }
}

/// The keyboard glyphs of a shortcut, drawn as keys.
struct KeyCaps: View {
    let caps: [String]
    var size: CGFloat = 12
    var tint: Color?

    var body: some View {
        HStack(spacing: Metrics.xs) {
            ForEach(Array(caps.enumerated()), id: \.offset) { _, cap in
                Text(cap)
                    .font(.system(size: size, weight: .medium))
                    .foregroundStyle(tint ?? .primary)
                    .frame(minWidth: size + 10, minHeight: size + 12)
                    .padding(.horizontal, 5)
                    .background(Color.controlWell, in: shape)
                    .overlay(shape.strokeBorder(Color.cardBorder, lineWidth: 1))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caps.joined(separator: " "))
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.radiusSmall, style: .continuous)
    }
}

/// A menu behind one glyph, sized like an `IconButton` and staying put.
///
/// `Menu` with the borderless style resizes its own label when it opens, so
/// the glyph shifted under the pointer on the way to the first item. Fixing
/// the frame and hiding the indicator keeps it still.
struct IconMenu<Content: View>: View {
    let symbol: String
    let help: String
    @ViewBuilder var content: Content

    var body: some View {
        Menu {
            content
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 24)
                .contentShape(RoundedRectangle(cornerRadius: Metrics.radiusSmall))
        }
        .menuStyle(.button)
        .buttonStyle(InteractiveButtonStyle(cornerRadius: Metrics.radiusSmall))
        .menuIndicator(.hidden)
        .frame(width: 26, height: 24)
        .hoverHelp(help)
        .accessibilityLabel(help)
    }
}

/// The close control on a dialog.
///
/// A glyph rather than the word "Done": nothing is being confirmed, the panel
/// is just being put away, and a text button beside a real action reads as a
/// second action of equal weight.
struct CloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 24)
                .contentShape(RoundedRectangle(cornerRadius: Metrics.radiusSmall))
        }
        .buttonStyle(InteractiveButtonStyle(cornerRadius: Metrics.radiusSmall))
        .keyboardShortcut(.cancelAction)
        .hoverHelp("Close")
        .accessibilityLabel("Close")
    }
}
