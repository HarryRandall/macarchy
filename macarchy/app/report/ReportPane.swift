import AppKit
import Macarchy
import SwiftUI

/// Files a problem on GitHub, after the person has read exactly what is sent.
///
/// Nothing leaves the Mac until they press a button, and the report shown is
/// the report sent: versions and check results, with their name, username,
/// computer name and home path already replaced.
struct ReportPane: View {
    @Environment(AppModel.self) private var model
    @State private var title = ""
    @State private var description = ""
    @State private var reportText = ""
    @State private var preparing = false
    @State private var notice: String?

    var body: some View {
        SettingsPage(
            "Report a problem", subtitle: "Tell us what went wrong. You see everything first."
        ) {
            knownIssues
            SettingsCard("Your report") {
                VStack(alignment: .leading, spacing: Metrics.medium) {
                    TextField("Short summary, such as “Bar disappears after sleep”", text: $title)
                        .textFieldStyle(.roundedBorder)
                    Text("What happened, and what you expected")
                        .font(.meta).foregroundStyle(.secondary)
                    TextEditor(text: $description)
                        .font(.body)
                        .frame(minHeight: 90)
                        .scrollContentBackground(.hidden)
                        .padding(Metrics.small)
                        .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6).strokeBorder(Color.cardBorder))
                }
                .padding(.horizontal, CardMetrics.horizontalPadding)
                .padding(.vertical, Metrics.medium)
            }
            SettingsCard(
                "What will be sent",
                help: "Versions and check results only. No logs, files or window titles."
            ) {
                ScrollView {
                    Text(reportText.isEmpty ? "Preparing…" : reportText)
                        .font(.monoDetail)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 140, maxHeight: 260)
                .padding(.horizontal, CardMetrics.horizontalPadding)
                .padding(.vertical, Metrics.medium)
            }
            HStack(spacing: Metrics.small) {
                if let notice { Text(notice).font(.meta).foregroundStyle(.secondary) }
                Spacer()
                Button("Copy report") { copy() }
                Button("Open on GitHub") { open() }
                    .buttonStyle(.borderedProminent)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || reportText.isEmpty)
                    .hoverHelp("Opens a new public issue in your browser for you to submit")
            }
        }
        .task(id: description) { await prepare() }
    }

    private var knownIssues: some View {
        SettingsCard("Known issues", help: "Problems with a known cause and a workaround.") {
            SettingRow(
                "Shortcuts stop working",
                detail:
                    "Secure Keyboard Entry in another app blocks skhd. Setup health names the app.")
            SettingRow(
                "Desktop switching does nothing",
                detail: "Needs yabai 7.1.25 or newer. Check Setup health for the installed version."
            )
            SettingRow("Something else?", detail: "See open issues before filing a new one.") {
                EmptyView()
            } accessory: {
                Button("Open issues") {
                    NSWorkspace.shared.open(Diagnostics.repository.appending(path: "issues"))
                }
            }
        }
    }

    private func prepare() async {
        preparing = true
        async let checks = Doctor.checks(integrations: model.backend)
        async let environment = Diagnostics.environment(integrations: model.backend)
        reportText = Diagnostics.report(
            title: title, description: Diagnostics.redact(description),
            environment: await environment, checks: await checks)
        preparing = false
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(reportText, forType: .string)
        notice = "Copied"
    }

    private func open() {
        let summary = Diagnostics.redact(title)
        if let url = Diagnostics.issueURL(title: summary, body: reportText) {
            NSWorkspace.shared.open(url)
            notice = nil
        } else {
            // Too long for a link: copy it and open a blank issue to paste into.
            copy()
            if let url = Diagnostics.issueURL(title: summary, body: "") {
                NSWorkspace.shared.open(url)
            }
            notice = "The report was too long for a link, so it is on your clipboard to paste."
        }
    }
}
