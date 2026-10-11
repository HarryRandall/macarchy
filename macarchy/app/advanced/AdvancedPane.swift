import SwiftUI
import Macarchy

struct AdvancedPane: View {
    @Environment(AppModel.self) private var model
    @State private var busy: Set<Daemon> = []
    @State private var restoring = false
    @State private var showAllBackups = false
    @State private var addition: ScriptingAddition.Status?
    @State private var repairingAddition = false
    @State private var wakeHelpers: Bool?

    var body: some View {
        SettingsPage("Advanced", subtitle: "Keep your desktop running smoothly.") {
            IconButton(symbol: "arrow.clockwise", help: "Check service status again") {
                Task {
                    await model.daemons.refresh()
                    await refreshCompatibility()
                }
            }
        } content: {
            AdvancedOverview()
            services
            configuration
            backups
            compatibility
        }
        .task {
            await model.daemons.refresh()
            model.snapshots.refresh()
            await refreshCompatibility()
        }
    }

    // MARK: - Services

    private var services: some View {
        SettingsCard(
            "Desktop services",
            help: "Restart a service if its feature stops responding. Stop turns that feature off."
        ) {
            ForEach(Array(Daemon.allCases.enumerated()), id: \.element) { index, daemon in
                SettingRow(
                    AdvancedOverview.serviceName(daemon),
                    help: AdvancedOverview.serviceDetail(daemon)
                ) {
                    Image(systemName: AdvancedOverview.serviceSymbol(daemon))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                } accessory: {
                    HStack(spacing: Metrics.small) {
                        StatusChip(
                            tone: isRunning(daemon) ? .good : .idle,
                            label: status(daemon),
                            live: isRunning(daemon))
                        ActionCluster {
                            IconButton(
                                symbol: "arrow.clockwise",
                                help:
                                    "Restart \(AdvancedOverview.serviceName(daemon).lowercased())",
                                isBusy: busy.contains(daemon)
                            ) { perform(daemon, stop: false) }
                            IconButton(
                                symbol: "stop.fill",
                                help: "Stop \(AdvancedOverview.serviceName(daemon).lowercased())",
                                isBusy: false
                            ) { perform(daemon, stop: true) }
                            .disabled(busy.contains(daemon) || !isRunning(daemon))
                        }
                    }
                    .motion(Motion.snappy, value: isRunning(daemon))
                }
                .appearStagger(index)
            }
        }
    }

    // MARK: - Configuration

    private var configuration: some View {
        SettingsCard(
            "Saved setup",
            help:
                "Rebuild files from saved preferences. Custom edits are backed up before replacement."
        ) {
            ForEach(Array(Self.generated.enumerated()), id: \.element.id) { index, entry in
                SettingRow(entry.title) {
                    Image(systemName: entry.symbol)
                        .font(.system(size: 13)).foregroundStyle(.secondary).frame(width: 20)
                } accessory: {
                    HStack(spacing: Metrics.small) {
                        outcomeBadge(model.rc.lastOutcomes[entry.file])
                        IconButton(symbol: "hammer", help: "Rebuild this file from preferences") {
                            switch entry.file {
                            case "bordersrc": model.rc.generateBordersRC()
                            case "yabairc": model.rc.generateYabaiRC()
                            default: model.rc.generateSketchybarRC()
                            }
                        }
                    }
                }
                .appearStagger(index)
            }
        }
    }

    /// The files the app generates, and how each is named to a reader.
    private struct Generated: Identifiable {
        let file: String
        let title: String
        let symbol: String
        var id: String { file }
    }

    private static let generated: [Generated] = [
        .init(file: "bordersrc", title: "Window borders", symbol: "square.dashed"),
        .init(file: "yabairc", title: "Window layout", symbol: "rectangle.3.group"),
        .init(file: "sketchybarrc", title: "Menu bar", symbol: "menubar.rectangle")
    ]

    // MARK: - Backups

    private var visibleSnapshots: [SnapshotStore.Snapshot] {
        showAllBackups ? model.snapshots.snapshots : Array(model.snapshots.snapshots.prefix(4))
    }

    private var backups: some View {
        SettingsCard(
            "Restore a previous setup",
            help:
                "Restore replaces current settings after backing them up. Changes create backups automatically."
        ) {
            if model.snapshots.snapshots.isEmpty {
                SettingRow(
                    "No backups yet",
                    detail: "Your saved setups will appear here when settings change.")
            }
            ForEach(Array(visibleSnapshots.enumerated()), id: \.element.id) { index, snapshot in
                SettingRow(
                    snapshot.created.formatted(date: .abbreviated, time: .shortened),
                    detail: snapshot.files.count == 1
                        ? "1 saved file" : "\(snapshot.files.count) saved files"
                ) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 13)).foregroundStyle(.secondary).frame(width: 20)
                } accessory: {
                    Button(restoring ? "Restoring…" : "Restore") { restore(snapshot) }
                        .disabled(restoring)
                }
                .appearStagger(index)
            }
            if model.snapshots.snapshots.count > 4 {
                Button {
                    withAnimation(Motion.snappy) { showAllBackups.toggle() }
                } label: {
                    HStack(spacing: Metrics.xs) {
                        Text(
                            showAllBackups
                                ? "Show fewer"
                                : "Show all \(model.snapshots.snapshots.count) backups")
                        Image(systemName: "chevron.down")
                            .rotationEffect(.degrees(showAllBackups ? 180 : 0))
                    }
                    .font(.meta)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Metrics.medium)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Compatibility

    private var compatibility: some View {
        SettingsCard(
            "Compatibility helpers",
            help: "Helpers for this macOS version, checked whenever the page opens."
        ) {
            SettingRow(
                "Switching between desktops",
                detail: addition?.explanation
                    ?? "A helper keeps desktop switching working on macOS 27."
            ) {
                HStack(spacing: Metrics.small) {
                    switch addition {
                    case .permitted:
                        StatusChip(tone: .good, label: "Active")
                    case nil:
                        StatusChip(tone: .idle, label: "Checking…")
                    case .bundleMissing, .binaryMissing:
                        StatusChip(tone: .bad, label: "Missing")
                    case .ruleMissing, .hashStale:
                        StatusChip(tone: .warning, label: "Needs repair")
                        Button(repairingAddition ? "Repairing…" : "Repair") { repairAddition() }
                            .disabled(repairingAddition)
                    }
                }
                .motion(Motion.snappy, value: addition)
            }
            SettingRow(
                "Recovering after sleep",
                help: "A wake-up helper restores window features that may stop responding "
                    + "after a long sleep."
            ) {
                switch wakeHelpers {
                case true: StatusChip(tone: .good, label: "Active")
                case false: StatusChip(tone: .warning, label: "Not registered")
                case nil: StatusChip(tone: .idle, label: "Checking…")
                }
            }
        }
    }

    /// Both rows used to read "Active" whether or not they were, which is how
    /// a broken desktop-switching helper went unnoticed for a day. They report
    /// what is actually installed now.
    private func refreshCompatibility() async {
        addition = ScriptingAddition.status()
        wakeHelpers = await model.wakeHelpersRegistered()
    }

    private func repairAddition() {
        repairingAddition = true
        Task {
            await model.repairScriptingAddition()
            await refreshCompatibility()
            repairingAddition = false
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func outcomeBadge(_ outcome: GeneratedFile.Outcome?) -> some View {
        switch outcome {
        case .written: StatusChip(tone: .good, label: "Rebuilt")
        case .unchanged: StatusChip(tone: .idle, label: "Up to date")
        case .writtenOverDrift: StatusChip(tone: .warning, label: "Edits backed up")
        case .failed(let message):
            StatusChip(tone: .bad, label: "Failed").hoverHelp(message)
        case nil: StatusChip(tone: .idle, label: "Not checked")
        }
    }

    private func restore(_ snapshot: SnapshotStore.Snapshot) {
        restoring = true
        Task {
            await model.snapshots.restore(snapshot)
            await model.loadEverything()
            restoring = false
        }
    }

    private func perform(_ daemon: Daemon, stop: Bool) {
        busy.insert(daemon)
        Task {
            if stop {
                await model.daemons.stop(daemon)
            } else {
                await model.daemons.restart(daemon)
            }
            busy.remove(daemon)
        }
    }

    private func isRunning(_ daemon: Daemon) -> Bool {
        model.daemons.states[daemon]?.isRunning == true
    }

    private func status(_ daemon: Daemon) -> String {
        switch model.daemons.states[daemon] ?? .unknown {
        case .running: "Running"
        case .stopped: "Stopped"
        case .unknown: "Unavailable"
        }
    }
}
