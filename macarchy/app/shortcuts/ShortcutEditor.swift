import Macarchy
import SwiftUI

/// Changes the key combination on one binding.
///
/// The command is shown but not editable: it is arbitrary shell, and the file
/// stays the place that decides what a shortcut does.
struct ShortcutEditor: View {
    @Environment(AppModel.self) private var model
    let binding: SkhdBinding
    let close: () -> Void

    @State private var chord: Chord
    @State private var confirmingDisable = false

    init(binding: SkhdBinding, close: @escaping () -> Void) {
        self.binding = binding
        self.close = close
        _chord = State(initialValue: Chord(binding))
    }

    private var conflict: SkhdBinding? {
        model.shortcuts.conflict(for: chord, excluding: binding)
    }

    private var changed: Bool { chord != Chord(binding) }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.cardGap) {
                    SettingsCard(
                        "Key combination",
                        help: "Record a new combination, then Save to update the shortcut."
                    ) {
                        VStack(alignment: .leading, spacing: Metrics.medium) {
                            KeyRecorder(chord: $chord, conflict: conflict)
                            if changed {
                                HStack(spacing: Metrics.small) {
                                    KeyCaps(
                                        caps: binding.keyCaps, size: 11,
                                        tint: Color.metaText)
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 10)).foregroundStyle(.secondary)
                                    KeyCaps(caps: chord.caps, size: 11)
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding(.horizontal, CardMetrics.horizontalPadding)
                        .padding(.vertical, Metrics.medium)
                    }

                    SettingsCard("What it does") {
                        if binding.command.isEmpty {
                            SettingRow(
                                "Different per app",
                                help: "Runs a different command in each app below.")
                        } else {
                            commandRow(binding.command)
                        }
                        ForEach(
                            Array(binding.appOverrides.enumerated()), id: \.offset
                        ) { _, entry in
                            SettingRow(entry.app) {
                                Text(entry.command)
                                    .font(.monoDetail).foregroundStyle(.secondary)
                                    .lineLimit(1).truncationMode(.middle)
                            }
                        }
                        if let section = binding.section {
                            SettingRow("Group") {
                                Text(section).font(.meta).foregroundStyle(.secondary)
                            }
                        }
                    }

                    if let message = model.shortcuts.lastError {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.meta).foregroundStyle(.orange)
                    }
                }
                .padding(Metrics.xl)
            }
            Divider()
            footer
        }
        .frame(width: 520, height: 560)
        .background(Color.paneBackground)
        .motion(Motion.snappy, value: changed)
    }

    private func commandRow(_ command: String) -> some View {
        SettingRow("Command") {
            Text(command)
                .font(.monoDetail).foregroundStyle(.secondary)
                .lineLimit(2).truncationMode(.middle).textSelection(.enabled)
                .frame(maxWidth: 280, alignment: .trailing)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Edit shortcut").font(.sectionTitle)
                Text(model.shortcuts.label(for: binding))
                    .font(.meta).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            KeyCaps(caps: chord.isEmpty ? binding.keyCaps : chord.caps)
        }
        .padding(Metrics.xl)
    }

    private var footer: some View {
        HStack(spacing: Metrics.small) {
            Button(confirmingDisable ? "Really disable?" : "Disable", role: .destructive) {
                if confirmingDisable {
                    Task {
                        if await model.shortcuts.disable(binding, daemons: model.daemons) {
                            close()
                        }
                    }
                } else {
                    withAnimation(Motion.snappy) { confirmingDisable = true }
                }
            }
            .hoverHelp("Comment this shortcut out, keeping it in the file")

            Spacer()

            Button("Cancel", action: close).keyboardShortcut(.cancelAction)
            Button(model.shortcuts.isSaving ? "Saving…" : "Save") {
                Task {
                    if await model.shortcuts.rebind(binding, to: chord, daemons: model.daemons) {
                        close()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!changed || chord.isEmpty || conflict != nil || model.shortcuts.isSaving)
            .hoverHelp(
                conflict == nil
                    ? "Write this combination and restart the service"
                    : "Another shortcut already uses this combination")
        }
        .padding(Metrics.xl)
    }
}
