import AppKit
import Macarchy
import SwiftUI

/// First run: check what is installed, preview every change, then set up.
///
/// Nothing is written until the person presses Set up. Each file Macarchy
/// replaces is backed up first, and Advanced can put them all back.
struct SetupView: View {
    @Environment(AppModel.self) private var model
    @State private var existing: Setup.Existing = .keep
    @State private var dependencies: [HealthCheck] = []
    @State private var running = false
    @State private var report: [String] = []
    @State private var error: String?
    @State private var finished = false

    private var missing: [Daemon] {
        Daemon.allCases.filter { !Paths.isInstalled($0.executableName) }
    }

    private var hasExistingConfig: Bool {
        Setup.plan(existing: existing).contains { $0.action == .adopt || $0.action == .replace }
    }

    var body: some View {
        SettingsPage("Set up Macarchy", subtitle: "A themed, tiling desktop in a few steps.") {
            if FileManager.default.fileExists(atPath: Paths.settings.path) {
                Button("Close") { model.showingSetup = false }
            }
        } content: {
            if finished { done } else { steps }
        }
    }

    @ViewBuilder
    private var steps: some View {
        SettingsCard(
            "1. Install the tools", help: "Macarchy configures these. It does not replace them."
        ) {
            ForEach(Daemon.allCases) { daemon in
                let installed = Paths.isInstalled(daemon.executableName)
                SettingRow(daemon.displayName, detail: installed ? "Installed" : daemon.role) {
                    Image(systemName: installed ? "checkmark.circle.fill" : "circle.dashed")
                        .foregroundStyle(installed ? .green : .secondary).frame(width: 20)
                } accessory: {
                    if !installed { copyButton(daemon.installCommand) }
                }
            }
            if !missing.isEmpty {
                SettingRow(
                    "Install everything",
                    detail: "Paste into Terminal. Needs Homebrew from brew.sh."
                ) {
                    EmptyView()
                } accessory: {
                    copyButton(brewCommand)
                }
            }
        }

        if hasExistingConfig {
            SettingsCard(
                "2. Your existing setup",
                help: "Either way, every original is backed up before anything changes."
            ) {
                Picker("Existing configuration", selection: $existing) {
                    Text("Keep mine and add Macarchy").tag(Setup.Existing.keep)
                    Text("Start fresh with Macarchy's defaults").tag(Setup.Existing.replace)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
                .padding(.horizontal, CardMetrics.horizontalPadding)
                .padding(.vertical, Metrics.medium)
            }
        }

        SettingsCard("\(hasExistingConfig ? 3 : 2). What will change") {
            ForEach(Setup.plan(existing: existing)) { change in
                SettingRow(Paths.display(change.path), detail: change.detail) {
                    Image(systemName: symbol(for: change.action))
                        .foregroundStyle(.secondary).frame(width: 20)
                } accessory: {
                    EmptyView()
                }
            }
        }

        HStack {
            if let error { Text(error).font(.meta).foregroundStyle(.red) }
            Spacer()
            Button(running ? "Setting up…" : "Set up Macarchy") { run() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(running)
                .hoverHelp(
                    missing.isEmpty
                        ? "Write the files above and start the services"
                        : "You can set up now and install the missing tools later")
        }
    }

    private var done: some View {
        Group {
            SettingsCard("Almost there") {
                SettingRow(
                    "Allow yabai and skhd",
                    detail: "macOS asks for Accessibility access the first time each runs. "
                        + "Turn both on, then restart them from Advanced."
                ) {
                    Image(systemName: "hand.raised").frame(width: 20)
                } accessory: {
                    Button("Open Accessibility") {
                        if let url = URL(
                            string:
                                "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                        ) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
                SettingRow(
                    "Separate Spaces",
                    detail: "Keep “Displays have separate Spaces” on in Desktop & Dock."
                ) {
                    Image(systemName: "rectangle.split.2x1").frame(width: 20)
                } accessory: {
                    EmptyView()
                }
            }
            SettingsCard("What setup did") {
                ForEach(report, id: \.self) { line in SettingRow(line) }
            }
            HStack {
                Spacer()
                Button("Check setup health") {
                    model.showingSetup = false
                    model.selection = .health
                }
                Button("Done") { model.showingSetup = false }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private var brewCommand: String {
        "brew install "
            + missing.map {
                $0.installCommand.replacingOccurrences(of: "brew install ", with: "")
            }.joined(separator: " ") + " jq"
    }

    private func copyButton(_ command: String) -> some View {
        Button("Copy command") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(command, forType: .string)
        }
        .hoverHelp(command)
    }

    private func symbol(for action: Setup.Change.Action) -> String {
        switch action {
        case .create: "plus.circle"
        case .adopt: "arrow.triangle.merge"
        case .replace: "arrow.triangle.2.circlepath"
        case .include: "text.badge.plus"
        case .link: "link"
        }
    }

    private func run() {
        running = true
        error = nil
        let choice = existing
        let app = Bundle.main.bundleURL.pathExtension == "app" ? Bundle.main.bundleURL : nil
        Task {
            do {
                report = try Setup.run(existing: choice, app: app)
                if let theme = try SettingsStore().read().currentTheme {
                    let applied = await ThemeApplication(integrations: model.backend).apply(
                        name: theme)
                    model.log.record(applied)
                    report.append(applied.ok ? applied.stdout : applied.stderr)
                }
                for result in await Setup.startServices(integrations: model.backend) {
                    model.log.record(result)
                    if !result.ok { report.append("\(result.command): \(result.summary)") }
                }
                await model.loadEverything()
                finished = true
            } catch {
                self.error = error.localizedDescription
            }
            running = false
        }
    }
}
