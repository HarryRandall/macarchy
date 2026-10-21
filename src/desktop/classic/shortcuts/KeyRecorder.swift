import AppKit
import Macarchy
import SwiftUI

/// Captures a real key chord by listening to the hardware.
///
/// Typing the chord is the only honest way to set one: a pair of pickers
/// cannot tell you that the combination is already taken by the system, and
/// people think in "the keys I press", not in a modifier list.
struct KeyRecorder: View {
    @Binding var chord: Chord
    var conflict: SkhdBinding?

    @State private var recording = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.small) {
            Button {
                withAnimation(Motion.snappy) { recording.toggle() }
            } label: {
                HStack(spacing: Metrics.small) {
                    Image(systemName: recording ? "record.circle" : "keyboard")
                        .font(.system(size: 13))
                        .foregroundStyle(recording ? .red : .secondary)
                        .symbolEffect(.pulse, isActive: recording && !reduceMotion)

                    if chord.isEmpty {
                        Text(recording ? "Press a key combination…" : "No shortcut set")
                            .font(.rowTitle).foregroundStyle(.secondary)
                    } else {
                        KeyCaps(caps: chord.caps)
                    }

                    Spacer(minLength: Metrics.small)

                    if recording {
                        Text("Esc to cancel").font(.badge).foregroundStyle(Color.metaText)
                    } else {
                        Text("Change").font(.meta).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, Metrics.medium)
                .padding(.vertical, Metrics.small)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    recording ? Color.accentColor.opacity(0.12) : Color.controlWell,
                    in: shape
                )
                .overlay(
                    shape.strokeBorder(
                        recording ? Color.accentColor : Color.cardBorder,
                        lineWidth: recording ? 2 : 1)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background {
                if recording {
                    KeyCaptureView { captured in
                        guard let captured else {
                            withAnimation(Motion.snappy) { recording = false }
                            return
                        }
                        withAnimation(Motion.snappy) {
                            chord = captured
                            recording = false
                        }
                    }
                }
            }
            .accessibilityLabel(
                chord.isEmpty ? "No shortcut set" : "Shortcut \(chord.caps.joined(separator: " "))"
            )
            .accessibilityHint("Activate, then press the key combination you want")

            if let conflict {
                Label {
                    Text("Already used by \(conflictName(conflict))")
                        .font(.meta)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 11))
                }
                .foregroundStyle(.orange)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .motion(Motion.snappy, value: conflict?.id)
    }

    private func conflictName(_ binding: SkhdBinding) -> String {
        guard let section = binding.section, !section.isEmpty else { return "another shortcut" }
        return section
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.radiusControl, style: .continuous)
    }
}

/// An invisible first responder that reports the next chord pressed.
private struct KeyCaptureView: NSViewRepresentable {
    /// `nil` means the capture was cancelled.
    let captured: (Chord?) -> Void

    func makeNSView(context: Context) -> CaptureView {
        let view = CaptureView()
        view.captured = captured
        return view
    }

    func updateNSView(_ view: CaptureView, context: Context) {
        view.captured = captured
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
    }

    final class CaptureView: NSView {
        var captured: ((Chord?) -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            // Escape alone cancels; escape with modifiers is a real chord.
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if event.keyCode == 53 && flags.isEmpty {
                captured?(nil)
                return
            }

            var modifiers: Set<String> = []
            if flags.contains(.command) { modifiers.insert("cmd") }
            if flags.contains(.option) { modifiers.insert("alt") }
            if flags.contains(.control) { modifiers.insert("ctrl") }
            if flags.contains(.shift) { modifiers.insert("shift") }

            guard let key = Self.name(for: event) else { return }
            captured?(Chord(modifiers: modifiers, key: key))
        }

        override func flagsChanged(with event: NSEvent) {
            // Modifiers alone are never a binding, so they are absorbed rather
            // than ending the capture early.
        }

        /// skhd's own spelling for the key, so what is written matches what it
        /// parses back.
        private static func name(for event: NSEvent) -> String? {
            if let special = specialKeys[event.keyCode] { return special }
            guard let characters = event.charactersIgnoringModifiers?.lowercased(),
                let first = characters.first, !first.isWhitespace
            else { return nil }
            return String(first)
        }

        private static let specialKeys: [UInt16: String] = [
            36: "return", 48: "tab", 49: "space", 51: "delete", 53: "escape",
            123: "left", 124: "right", 125: "down", 126: "up",
            115: "home", 119: "end", 116: "pageup", 121: "pagedown",
            122: "f1", 120: "f2", 99: "f3", 118: "f4", 96: "f5", 97: "f6",
            98: "f7", 100: "f8", 101: "f9", 109: "f10", 103: "f11", 111: "f12"
        ]
    }
}
