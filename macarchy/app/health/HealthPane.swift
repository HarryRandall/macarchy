import AppKit
import Macarchy
import SwiftUI

/// What is installed, what is working and what needs attention.
///
/// Every row comes from the same checks as `macarchy doctor`. Nothing here
/// changes the desktop; fixes are commands to copy or a page to visit.
struct HealthPane: View {
    @Environment(AppModel.self) private var model
    @State private var checks: [HealthCheck] = []
    @State private var environment: Diagnostics.Environment?
    @State private var checking = false
    @State private var checkedAt: Date?

    var body: some View {
        SettingsPage("Setup health", subtitle: "What is installed, and what needs attention.") {
            Button {
                Task { await refresh() }
            } label: {
                Label(checking ? "Checking…" : "Check again", systemImage: "arrow.clockwise")
            }
            .disabled(checking)
            Button("Report a problem") {
                withAnimation(Motion.snappy) { model.selection = .report }
            }
        } content: {
            summary
            ForEach(HealthCheck.Group.allCases, id: \.self) { group in
                let members = checks.filter { $0.group == group }
                if !members.isEmpty {
                    SettingsCard(group.rawValue, help: help(for: group)) {
                        ForEach(members) { row($0) }
                    }
                }
            }
            if let environment { machine(environment) }
        }
        .task { await refresh() }
    }

    private var summary: some View {
        let failed = checks.filter { $0.status == .failed }.count
        let warnings = checks.filter { $0.status == .warning }.count
        return HStack(spacing: Metrics.small) {
            if checks.isEmpty {
                StatusChip(tone: .idle, label: "Checking")
            } else if failed == 0 {
                StatusChip(tone: .good, label: "Everything Macarchy needs is working")
            } else {
                StatusChip(tone: .bad, label: "\(failed) to fix")
            }
            if warnings > 0 { StatusChip(tone: .warning, label: "\(warnings) to review") }
            Spacer()
            if let checkedAt {
                Text("Checked \(checkedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.meta).foregroundStyle(Color.metaText)
            }
        }
    }

    private func row(_ check: HealthCheck) -> some View {
        SettingRow(check.title, detail: check.detail.isEmpty ? nil : check.detail) {
            Image(systemName: symbol(for: check.status))
                .font(.system(size: 13)).foregroundStyle(tone(for: check.status).colour)
                .frame(width: 20)
        } accessory: {
            if let fix = check.fix, check.status != .passed {
                Button("Copy fix") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(fix, forType: .string)
                }
                .hoverHelp(fix)
            }
        }
    }

    private func machine(_ environment: Diagnostics.Environment) -> some View {
        SettingsCard("This Mac", help: "Included in problem reports, without your name or paths.") {
            SettingRow("Mac", detail: "\(environment.model) · \(environment.architecture)")
            SettingRow("macOS", detail: environment.macOS)
            SettingRow("Macarchy", detail: environment.app)
            SettingRow("Settings folder", detail: Paths.display(Paths.appRoot)) {
                EmptyView()
            } accessory: {
                Button("Reveal") {
                    NSWorkspace.shared.activateFileViewerSelecting([Paths.appRoot])
                }
            }
        }
    }

    private func refresh() async {
        checking = true
        async let found = Doctor.checks(integrations: model.backend)
        async let facts = Diagnostics.environment(integrations: model.backend)
        checks = await found
        environment = await facts
        checkedAt = .now
        checking = false
    }

    private func help(for group: HealthCheck.Group) -> String {
        switch group {
        case .dependencies: "The programs Macarchy configures. Install any that are missing."
        case .services: "Whether each program is set to start at login and is running."
        case .configuration: "Macarchy's settings and the startup files it writes."
        case .optional: "Extras that are not needed for Macarchy to work."
        }
    }

    private func symbol(for status: HealthCheck.Status) -> String {
        switch status {
        case .passed: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .failed: "xmark.octagon.fill"
        case .unknown: "questionmark.circle"
        }
    }

    private func tone(for status: HealthCheck.Status) -> StatusChip.Tone {
        switch status {
        case .passed: .good
        case .warning: .warning
        case .failed: .bad
        case .unknown: .idle
        }
    }
}
