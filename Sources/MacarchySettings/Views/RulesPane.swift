import SwiftUI
import AppKit

struct RulesPane: View {
    @Environment(AppModel.self) private var model

    private var owned: [RulesModel.Rule] { model.rules.rules.filter { $0.source == .floatState } }
    private var declared: [RulesModel.Rule] { model.rules.rules.filter { $0.source == .declared } }

    var body: some View {
        Form {
            Section {
                if owned.isEmpty {
                    Text("No floating apps yet.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(owned) { rule in
                        LabeledContent {
                            Button {
                                Task { await model.rules.remove(rule) }
                            } label: {
                                Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Stop floating \(rule.app)")
                        } label: {
                            HStack(spacing: 8) {
                                AppIcon(name: rule.app)
                                Text(rule.app)
                            }
                        }
                    }
                }

                Button("Add Application…") { pickApp() }
                    .controlSize(.small)
                    .disabled(model.rules.isBusy)
            } header: {
                Text("Floating apps · \(owned.count)")
            } footer: {
                Text("Kept in float_state.json and reapplied by sync_float_rules.sh, so they survive a yabai restart.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if !declared.isEmpty {
                Section {
                    ForEach(declared) { rule in
                        LabeledContent {
                            Text("read-only")
                                .font(.caption2).foregroundStyle(.tertiary)
                        } label: {
                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 8) {
                                    AppIcon(name: rule.app)
                                    Text(rule.app)
                                }
                                if let title = rule.title {
                                    Text("windows matching \(title)")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Declared in yabairc · \(declared.count)")
                } footer: {
                    Text("Hand-written rules inside yabairc's macarchy:keep region. The app never rewrites these.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .task { await model.rules.reload() }
    }

    private func pickApp() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Float"
        panel.message = "Choose an application yabai should leave untiled"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        // yabai matches on the localised app name, which is the bundle's display
        // name, not the filename — they differ for some apps.
        let name = FileManager.default.displayName(atPath: url.path)
            .replacingOccurrences(of: ".app", with: "")
        Task { await model.rules.add(name) }
    }
}

/// The real app icon when it can be found; a neutral placeholder otherwise.
private struct AppIcon: View {
    let name: String

    var body: some View {
        if let path = Self.path(for: name) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                .resizable().frame(width: 16, height: 16)
        } else {
            Image(systemName: "app.dashed")
                .foregroundStyle(.tertiary).frame(width: 16, height: 16)
        }
    }

    private static func path(for name: String) -> String? {
        for root in ["/Applications", "/System/Applications",
                     NSHomeDirectory() + "/Applications",
                     "/System/Applications/Utilities"] {
            let candidate = "\(root)/\(name).app"
            if FileManager.default.fileExists(atPath: candidate) { return candidate }
        }
        return nil
    }
}
