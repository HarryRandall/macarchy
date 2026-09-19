import SwiftUI

extension BordersPane {
    func previewCard() -> some View {
        SettingsCard {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Toggle(
                        "Live preview",
                        isOn: Binding(
                            get: { editor.live }, set: { editor.setLive($0) }
                        )
                    )
                    .toggleStyle(.switch).controlSize(.small)
                    .disabled(!editor.live && (editor.isApplying || editor.hasChanges))
                    HelpTooltip(
                        text: "Live applies edits and resets immediately. Turn it off to compare "
                            + "Before and After, then choose Apply or Discard. Apply or discard pending edits "
                            + "before turning Live back on. Corner changes still need new windows.")
                    Spacer()
                    if !editor.live {
                        Button("Discard") { editor.discard() }
                            .disabled(!editor.hasChanges || editor.isApplying)
                        Button(editor.isApplying ? "Applying..." : "Apply") {
                            Task { await editor.apply() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!editor.hasChanges || editor.isApplying)
                    }
                }
                BorderPreview(
                    appearance: editor.draft,
                    before: editor.live ? nil : editor.applied,
                    wallpaper: model.currentThemeWallpaper
                )
                HStack {
                    Text(
                        editor.live
                            ? "Changes apply as you edit."
                            : "Changes stay in this preview until you apply them."
                    )
                    .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if editor.isApplying {
                        ProgressView().controlSize(.small)
                    } else if editor.hasChanges {
                        Text("Unsaved changes").font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let error = editor.error {
                    Text(error).font(.caption).foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }.padding(12)
        }
    }
}
