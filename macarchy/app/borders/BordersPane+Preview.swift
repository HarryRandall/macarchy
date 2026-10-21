import SwiftUI

extension BordersPane {
    func previewHeader() -> some View {
        previewCard()
            .padding(.top, editor.live ? 0 : Metrics.large)
            .background(Color.paneBackground)
            .padding(.bottom, Metrics.cardGap)
    }

    func previewCard() -> some View {
        SettingsCard {
            VStack(spacing: Metrics.medium) {
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
                        text: "Apply edits straight away, or hold them for a before and after")
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
                if editor.isApplying || editor.hasChanges {
                    HStack {
                        Spacer()
                        if editor.isApplying {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Unsaved changes").font(.meta).foregroundStyle(.secondary)
                        }
                    }
                }
                if let error = editor.error {
                    Text(error).font(.meta).foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }.padding(Metrics.medium)
        }
    }
}
