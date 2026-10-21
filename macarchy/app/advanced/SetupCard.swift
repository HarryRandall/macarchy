import Macarchy
import SwiftUI

/// Re-running setup, and undoing it.
struct SetupCard: View {
    @Environment(AppModel.self) private var model
    @State private var confirmingRestore = false
    @State private var working = false

    var body: some View {
        SettingsCard(
            "Setup",
            help: "Setup backed up every file it replaced. Restoring puts them all back."
        ) {
            SettingRow(
                "Run setup again",
                detail: "Repairs startup files and the app link. Your edits are kept."
            ) {
                EmptyView()
            } accessory: {
                Button("Open setup") { model.showingSetup = true }
            }
            SettingRow(
                "Restore original files",
                detail: "Puts back the configs you had before Macarchy, in "
                    + Paths.display(Paths.backupsDirectory)
            ) {
                EmptyView()
            } accessory: {
                Button(confirmingRestore ? "Really restore?" : "Restore", role: .destructive) {
                    if confirmingRestore { restore() } else { confirmingRestore = true }
                }
                .disabled(working)
            }
        }
    }

    private func restore() {
        working = true
        Task {
            do {
                let report = try await Setup.uninstall()
                model.log.note("restored original files", report.joined(separator: "\n"))
                for result in await Setup.startServices(integrations: model.backend) {
                    model.log.record(result)
                }
            } catch {
                model.log.failure("restore originals failed", error.localizedDescription)
            }
            confirmingRestore = false
            working = false
        }
    }
}
