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
    private var lastShell: ShellState?
    private var watcher: DispatchSourceFileSystemObject?
    private var lastSettings: Data?
    private var pendingReload: Task<Void, Never>?

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
        lastShell = model.shellState()
        observe()
        watchSettings()
    }

    /// Records a save the app made itself, so the watcher does not treat it
    /// as an outside change and re-read yabai under an edit still in progress.
    func settingsWritten() {
        guard let model else { return }
        lastSettings = try? Data(contentsOf: model.settingsStore.url)
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

    /// Pages that have loaded. One still loading fetches current state itself.
    private var surfaces: [WebSurface] { [settings(), switcher()].compactMap { $0 } }

    private func observe() {
        guard let model else { return }
        withObservationTracking {
            _ = model.themes.themes
            _ = model.themes.current
            _ = model.daemons.states
        } onChange: { [weak self] in
            // Runs before the change lands; read the new values afterwards.
            Task { @MainActor in
                self?.publish()
                self?.observe()
            }
        }
    }

    private func publish() {
        guard let model else { return }
        let themes = model.switcherState()
        if themes != lastThemes {
            lastThemes = themes
            for surface in surfaces { surface.send(.themesChanged(themes)) }
            // The Layout preview shows the theme's wallpaper.
            if let snapshot = model.layout {
                settings()?.send(.layoutChanged(model.layoutState(snapshot)))
            }
        }
        // Setup creates the settings folder during the session.
        if watcher == nil { watchSettings() }
        let shell = model.shellState()
        if shell != lastShell {
            lastShell = shell
            settings()?.send(.shellChanged(shell))
        }
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
    private func settingsFolderChanged() {
        pendingReload?.cancel()
        pendingReload = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled, let self, let model = self.model else { return }
            let data = try? Data(contentsOf: model.settingsStore.url)
            guard data != self.lastSettings else { return }
            self.lastSettings = data
            model.themes.reload()
            await self.publishRules(model)
            if let snapshot = await model.refreshLayout() {
                self.settings()?.send(.layoutChanged(model.layoutState(snapshot)))
            }
        }
    }
}
