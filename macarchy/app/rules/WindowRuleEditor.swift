import Macarchy
import SwiftUI

struct WindowRuleEditor: View {
    @Environment(AppModel.self) private var model
    let rule: CustomWindowRule?
    let close: () -> Void
    @State private var app: String
    @State private var title: String
    @State private var error: String?
    private let ruleID: String

    init(rule: CustomWindowRule?, close: @escaping () -> Void) {
        self.rule = rule
        self.close = close
        ruleID = rule?.id ?? UUID().uuidString
        _app = State(initialValue: rule?.app ?? "")
        _title = State(initialValue: rule?.title ?? "")
    }

    private var candidate: CustomWindowRule {
        CustomWindowRule(id: ruleID, app: app, title: title)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(
                    model.rules.customRules.contains { $0.id == ruleID }
                        ? "Edit custom rule" : "Add custom rule"
                ).font(.sectionTitle)
                HelpTooltip(
                    text:
                        "Matching windows float outside the tiled layout. Nothing changes until you Save."
                )
                Spacer()
                CloseButton(action: close)
            }.padding(Metrics.large)
            Divider()
            VStack(alignment: .leading, spacing: Metrics.medium) {
                SettingsCard("Match windows") {
                    SettingRow(
                        "Application",
                        help:
                            "Enter the application's display name exactly, for example Finder or Calculator."
                    ) {
                        TextField("For example, Finder", text: $app)
                            .textFieldStyle(.roundedBorder).frame(width: 240)
                    }
                    SettingRow(
                        "Window title",
                        help:
                            "Optional regular expression. For example, ^Copy$ matches Copy exactly. Leave empty for all windows."
                    ) {
                        TextField("All windows", text: $title)
                            .textFieldStyle(.roundedBorder).frame(width: 240)
                    }
                }
                HStack {
                    Menu("Presets") {
                        Button("Finder file dialogs") {
                            app = "Finder"; title = "^Copy$|^Move$|^Delete$|^Trash$"
                        }
                        Button("Calculator") {
                            app = "Calculator"; title = ""
                        }
                        Button("Blank rule") {
                            app = ""; title = ""
                        }
                    }
                    HelpTooltip(
                        text: "Presets fill the fields. Adjust them and Save to enable the rule.")
                    Spacer()
                }
                if let error {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.meta).foregroundStyle(.orange)
                }
            }.padding(Metrics.large)
            Divider()
            HStack {
                Spacer()
                Button("Cancel", action: close)
                Button(model.rules.isBusy ? "Saving…" : "Save") {
                    let draft = candidate
                    do { try draft.validate() } catch {
                        self.error = error.localizedDescription
                        return
                    }
                    Task {
                        if await model.rules.saveCustom(draft) {
                            close()
                        } else {
                            error = model.rules.lastError
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    app.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || model.rules.isBusy)
            }.padding(Metrics.large)
        }
        .frame(width: 570)
        .background(Color.paneBackground)
    }
}
