import Foundation
import Macarchy
import Observation

/// Tells every open page when shared state changes, wherever the change came
/// from: the status menu, the classic window, the switcher or the CLI.
///
/// In-app changes are seen by observing the models the status menu reads.
/// Changes from outside, such as `macarchy theme next` bound in skhd, arrive
/// as a new `settings.json`, which the watcher turns into a reload of those
/// same models.
@MainActor
final class StateBroadcast {
    static let shared = StateBroadcast(
        settings: { SettingsWindow.shared.surface }, switcher: { ThemeSwitcher.shared.surface })

    private let settings: @MainActor () -> WebSurface?
    private let switcher: @MainActor () -> WebSurface?
    private var model: AppModel?
    private var lastThemes: SwitcherState?
    private var lastThemeRevision = -1
    private var lastShell: ShellState?
    private var lastMaintenance = ""
    private var watcher: DispatchSourceFileSystemObject?
    private let shortcutsBroadcast = ShortcutsBroadcast()
    private var lastSettings: Data?
    private let homeFiles = HomeFileWatch()
    private var reloadGeneration = 0
    private var overviewHolds = 0
    private var overviewDue = false

    init(
        settings: @escaping @MainActor () -> WebSurface?,
        switcher: @escaping @MainActor () -> WebSurface?
    ) {
        self.settings = settings
        self.switcher = switcher
    }

    func start(_ model: AppModel) {
        self.model = model
        lastSettings = try? Data(contentsOf: model.settingsStore.url)
        lastThemes = model.switcherState()
        lastThemeRevision = model.themes.revision
        lastShell = model.shellState()
        observe()
        watchSettings()
        homeFiles.start { [weak self] in self?.publishOverview() }
        shortcutsBroadcast.start { [weak self] event in self?.settings()?.send(event) }
    }

    func shortcutsWritten(_ state: ShortcutsState) {
        shortcutsBroadcast.written(state)
        settings()?.send(.shortcutsChanged(state))
    }

    /// Records a save the app made itself, so the watcher does not treat it
    /// as an outside change and re-read yabai under an edit still in progress.
    func settingsWritten() {
        guard let model else { return }
        lastSettings = try? Data(contentsOf: model.settingsStore.url)
        publishOverview()
    }

    func rulesWritten(_ model: AppModel) async {
        settingsWritten()
        await publishRules(model)
    }

    private func publishRules(_ model: AppModel) async {
        do {
            settings()?.send(.rulesChanged(try await model.readRulesState()))
        } catch {
            model.log.failure("read rules", error.localizedDescription)
            settings()?.send(.rulesUnavailable(error.localizedDescription))
        }
    }

    func advancedChanged() {
        guard let model else { return }
        settings()?.send(.shellChanged(model.shellState()))
        Task {
            do {
                settings()?.send(.advancedChanged(try await model.advancedState()))
            } catch {
                settings()?.send(.advancedInvalidated)
            }
        }
    }

    /// Pages that have loaded. One still loading fetches current state itself.
    private var surfaces: [WebSurface] { [settings(), switcher()].compactMap { $0 } }

    private func observe() {
        guard let model else { return }
        withObservationTracking {
            _ = model.themes.themes
            _ = model.themes.current
            _ = model.themes.revision
            _ = model.daemons.states
            _ = model.layout
            _ = model.shortcuts.bindings
            _ = model.snapshots.snapshots
        } onChange: { [weak self] in
            // Runs before the change lands; read the new values afterwards.
            Task { @MainActor in
                self?.publish()
                self?.observe()
                await self?.publishBorders()
            }
        }
    }

    private func publishBorders() async {
        guard let model else { return }
        do { settings()?.send(.bordersChanged(try await model.bordersState())) } catch {
            model.log.failure("refresh borders", error.localizedDescription)
        }
    }

    private func publish() {
        guard let model else { return }
        publishOverview()
        let themes = model.switcherState()
        if themes != lastThemes || model.themes.revision != lastThemeRevision {
            lastThemeRevision = model.themes.revision
            lastThemes = themes
            for surface in surfaces { surface.send(.themesChanged(themes)) }
            // The Layout preview shows the theme's wallpaper.
            if let snapshot = model.layout {
                settings()?.send(.layoutChanged(model.layoutState(snapshot)))
            }
        }
        let maintenance =
            Daemon.allCases.map { String(describing: model.daemons.states[$0]) }.joined()
            + model.snapshots.snapshots.map(\.id).joined()
            + (model.themes.current ?? "") + String(model.themes.themes.count)
        if maintenance != lastMaintenance {
            lastMaintenance = maintenance
            settings()?.send(.advancedInvalidated)
        }
        // Setup creates the settings folder during the session.
        if watcher == nil { watchSettings() }
        let shell = model.shellState()
        if shell != lastShell {
            lastShell = shell
            settings()?.send(.shellChanged(shell))
        }
    }

    /// Health reruns slow checks on every event, so while an outside change reloads
    /// several models, each of which notifies `observe`, the event is sent once at the end.
    private func publishOverview() {
        guard overviewHolds == 0 else {
            overviewDue = true
            return
        }
        settings()?.send(.homeChanged)
        settings()?.send(.healthChanged)
    }

    /// `settings.json` is replaced atomically, so the folder is watched rather
    /// than the file: the file's descriptor would go stale on the first save.
    private func watchSettings() {
        guard let model else { return }
        let folder = model.settingsStore.url.deletingLastPathComponent()
        let descriptor = open(folder.path, O_EVTONLY)
        // Before setup the folder does not exist; `publish` tries again.
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor, eventMask: [.write, .rename, .delete], queue: .main)
        source.setEventHandler { [weak self, weak source] in
            MainActor.assumeIsolated {
                // A folder moved or deleted leaves this descriptor pointing at
                // nothing; start again on whatever is at the path now.
                if let source, !source.data.isDisjoint(with: [.rename, .delete]) {
                    source.cancel()
                    self?.watcher = nil
                    self?.watchSettings()
                }
                self?.settingsFolderChanged()
            }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        watcher = source
    }

    /// Several writes land together (a snapshot, then the settings), so wait
    /// for them to settle and act only if the settings themselves changed.
    ///
    /// A later event only replaces a reload still waiting. One already reading
    /// runs to the end: cancelling it would kill its yabai commands, which read
    /// as yabai not responding and briefly reach the page.
    private func settingsFolderChanged() {
        reloadGeneration += 1
        let generation = reloadGeneration
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard let self, generation == self.reloadGeneration, let model = self.model else {
                return
            }
            let data = try? Data(contentsOf: model.settingsStore.url)
            guard data != self.lastSettings else { return }
            self.lastSettings = data
            self.overviewHolds += 1
            self.overviewDue = true
            self.advancedChanged()
            model.themes.reload()
            await self.publishRules(model)
            await self.publishBorders()
            if let snapshot = await model.refreshLayout() {
                self.settings()?.send(.layoutChanged(model.layoutState(snapshot)))
            }
            // Observers of the models reloaded above are queued behind this task, so
            // release the hold after them.
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.overviewHolds -= 1
                if self.overviewHolds == 0, self.overviewDue {
                    self.overviewDue = false
                    self.publishOverview()
                }
            }
        }
    }
}
