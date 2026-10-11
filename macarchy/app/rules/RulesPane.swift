import SwiftUI
import AppKit
import Macarchy

struct RulesPane: View {
    @Environment(AppModel.self) private var model

    private var owned: [RulesModel.Rule] { model.rules.rules.filter { $0.source == .floatState } }
    private var declared: [RulesModel.Rule] { model.rules.rules.filter { $0.source == .declared } }

    var body: some View {
        SettingsPage("Rules", subtitle: "Apps that sit outside the layout.") {
            Menu("Add", systemImage: "plus") {
                Button("Add application…") { pickApp() }
                Button("Add custom rule…") { editCustom() }
                Divider()
                Button("Finder file dialogs…") {
                    editCustom(
                        CustomWindowRule(app: "Finder", title: "^Copy$|^Move$|^Delete$|^Trash$"))
                }
                Button("Calculator…") { editCustom(CustomWindowRule(app: "Calculator")) }
            }
            .disabled(model.rules.isBusy)
            .hoverHelp(
                "Add an app to float all its windows, or a custom rule for specific window titles.")
        } content: {
            SettingsCard(
                "Floating apps",
                help: "These apps keep their own window size and position instead of being "
                    + "tiled. The list survives a restart of the window manager."
            ) {
                if owned.isEmpty {
                    SettingRow(
                        "No floating apps yet",
                        help:
                            "Use Add application to choose an app that should stay outside the tiled layout."
                    )
                }
                ForEach(owned) { rule in
                    SettingRow(rule.app) {
                        AppIcon(name: rule.app)
                    } accessory: {
                        Button {
                            Task { await model.rules.remove(rule) }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.secondary)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .hoverHelp("Stop floating \(rule.app)")
                        .accessibilityLabel("Stop floating \(rule.app)")
                        .disabled(model.rules.isBusy)
                    }
                }
            }

            customRulesCard
            if let error = model.rules.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.meta).foregroundStyle(.orange)
            }
            if !declared.isEmpty {
                SettingsCard(
                    "External rules",
                    help:
                        "Rules managed outside Macarchy. Change them in your window manager configuration."
                ) {
                    ForEach(declared) { rule in
                        SettingRow(rule.app, detail: rule.title.map { "Windows matching \($0)" }) {
                            AppIcon(name: rule.app)
                        } accessory: {
                            Text("Read only")
                                .font(.meta)
                                .foregroundStyle(Color.metaText)
                        }
                    }
                }
            }
        }
        .task { await model.rules.reload() }
    }

    private var customRulesCard: some View {
        SettingsCard(
            "Custom rules",
            help:
                "Match an application and optional window title pattern. Use a preset or add your own."
        ) {
            if model.rules.customRules.isEmpty {
                SettingRow(
                    "No custom rules", help: "Choose Add custom rule or a preset from the Add menu."
                )
            }
            ForEach(model.rules.customRules) { rule in
                SettingRow(rule.app, detail: rule.title.isEmpty ? "All windows" : rule.title) {
                    AppIcon(name: rule.app)
                } accessory: {
                    HStack {
                        IconButton(symbol: "pencil", help: "Edit rule for \(rule.app)") {
                            editCustom(rule)
                        }
                        IconButton(symbol: "minus.circle", help: "Remove rule for \(rule.app)") {
                            Task { await model.rules.removeCustom(rule) }
                        }
                    }.disabled(model.rules.isBusy)
                }
            }
        }
    }

    private func editCustom(_ rule: CustomWindowRule? = nil) {
        model.modal.present {
            WindowRuleEditor(rule: rule) { model.modal.dismiss() }
        }
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
struct AppIcon: View {
    let name: String

    var body: some View {
        if let path = Self.path(for: name) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                .resizable().frame(width: 18, height: 18)
        } else {
            Image(systemName: "app.dashed")
                .foregroundStyle(.secondary).frame(width: 18, height: 18)
        }
    }

    private static func path(for name: String) -> String? {
        for root in [
            "/Applications", "/System/Applications",
            NSHomeDirectory() + "/Applications",
            "/System/Applications/Utilities"
        ] {
            let candidate = "\(root)/\(name).app"
            if FileManager.default.fileExists(atPath: candidate) { return candidate }
        }
        return nil
    }
}
