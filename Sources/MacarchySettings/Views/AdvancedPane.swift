import SwiftUI

struct AdvancedPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section("Daemons") {
                ForEach(Daemon.allCases) { daemon in
                    LabeledContent {
                        HStack(spacing: 8) {
                            StatusBadge(state: model.daemons.states[daemon] ?? .unknown)
                            Button("Restart") { Task { await model.daemons.restart(daemon) } }
                                .controlSize(.small)
                            Button("Stop") { Task { await model.daemons.stop(daemon) } }
                                .controlSize(.small)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(daemon.displayName)
                            Text(daemon.launchdLabel)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Button("Refresh") { Task { await model.daemons.refresh() } }
                    .controlSize(.small)
            }

            Section {
                workaround("macOS 27 Space switching",
                           detail: "switch_space_macos27.sh · InstantSpaceSwitcher PR #88 · added 16 Sep 2026")
                workaround("Scripting addition reload on wake",
                           detail: "Deep sleep breaks the SA and borders until the Dock restarts")
            } header: {
                Text("Active workarounds")
            } footer: {
                Text("Surfaced here so a stopgap cannot quietly become permanent.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                if model.snapshots.snapshots.isEmpty {
                    Text("No snapshots yet. One is taken before each write.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.snapshots.snapshots) { snapshot in
                        LabeledContent {
                            Button("Restore") { model.snapshots.restore(snapshot) }
                                .controlSize(.small)
                        } label: {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(snapshot.id.replacingOccurrences(of: "T", with: "  "))
                                    .font(.system(size: 12, design: .monospaced))
                                Text(captionFor(snapshot))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
                Button("Refresh") { model.snapshots.refresh() }
                    .controlSize(.small)
            } header: {
                Text("Snapshots · keeping last 20")
            } footer: {
                Text("Taken automatically before each write. Restoring snapshots the current state first, so it is itself undoable.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .task { await model.daemons.refresh(); model.snapshots.refresh() }
    }

    private func captionFor(_ snapshot: SnapshotStore.Snapshot) -> String {
        let reason = model.snapshots.reason(for: snapshot)
        let files = snapshot.files.count == 1 ? "1 file" : "\(snapshot.files.count) files"
        return reason.isEmpty ? files : "\(reason) · \(files)"
    }

    private func workaround(_ title: String, detail: String) -> some View {
        LabeledContent {
            Text("active")
                .font(.caption2)
                .foregroundStyle(.orange)
        } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

private struct StatusBadge: View {
    let state: DaemonState

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(state.isRunning ? Color.green : Color.secondary)
                .frame(width: 6, height: 6)
            Text(state.label)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .frame(width: 104, alignment: .leading)
    }
}
