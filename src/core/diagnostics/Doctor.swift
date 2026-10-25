import Foundation

/// One finding about the desktop, shared by `macarchy doctor` and the app.
public struct HealthCheck: Sendable, Identifiable, Equatable {
    public enum Group: String, Sendable, CaseIterable {
        case dependencies = "Dependencies"
        case services = "Services"
        case configuration = "Configuration"
        case optional = "Optional"
    }

    public enum Status: String, Sendable {
        case passed, warning, failed, unknown
    }

    public let group: Group
    public let title: String
    public let status: Status
    public let detail: String
    /// What to do about it, in words, when that is not a command.
    public let fix: String?
    /// A shell command that fixes it, ready to paste into Terminal.
    public let command: String?
    /// The file to open when the fix is to correct it by hand.
    public let file: URL?

    public var id: String { group.rawValue + "/" + title }

    public init(
        _ group: Group, _ title: String, _ status: Status, _ detail: String = "",
        fix: String? = nil, command: String? = nil, file: URL? = nil
    ) {
        self.group = group
        self.title = title
        self.status = status
        self.detail = detail
        self.fix = fix
        self.command = command
        self.file = file
    }
}

/// Read-only checks, in the order a person would fix them.
public enum Doctor {
    public static func checks(integrations: Integrations = Integrations()) async -> [HealthCheck] {
        var results = dependencyChecks()
        results += await serviceChecks(integrations: integrations)
        results += await configurationChecks(integrations: integrations)
        results += optionalChecks()
        return results
    }

    /// Text form for the command line. Warnings do not fail the command.
    public static func check(integrations: Integrations = Integrations()) async -> CommandResult {
        let results = await checks(integrations: integrations)
        var lines: [String] = []
        for group in HealthCheck.Group.allCases {
            let members = results.filter { $0.group == group }
            guard !members.isEmpty else { continue }
            lines.append(group.rawValue)
            for check in members {
                let mark =
                    switch check.status {
                    case .passed: "ok  "
                    case .warning: "warn"
                    case .failed: "FAIL"
                    case .unknown: "?   "
                    }
                var line = "  \(mark) \(check.title)"
                if !check.detail.isEmpty { line += ": \(check.detail)" }
                lines.append(line)
                if check.status != .passed {
                    if let fix = check.fix { lines.append("       \(fix)") }
                    if let command = check.command { lines.append("       Run: \(command)") }
                }
            }
        }
        let failures = results.filter { $0.status == .failed }.count
        lines.append(failures == 0 ? "No problems found" : "\(failures) problem(s) to fix")
        return CommandResult(
            command: "doctor", status: failures == 0 ? 0 : 1, stdout: lines.joined(separator: "\n"),
            stderr: failures == 0 ? "" : "Desktop checks failed")
    }

    static func dependencyChecks() -> [HealthCheck] {
        var results = Daemon.allCases.map { daemon in
            Paths.isInstalled(daemon.executableName)
                ? HealthCheck(
                    .dependencies, daemon.displayName, .passed,
                    Paths.display(
                        URL(fileURLWithPath: daemon.executable)))
                : HealthCheck(
                    .dependencies, daemon.displayName, .failed, "Not installed",
                    command: daemon.installCommand)
        }
        // The bundled bar's Space labels read yabai's JSON through jq.
        if (try? SettingsStore().read().bundledBar) ?? true != false {
            results.append(
                Paths.isInstalled("jq")
                    ? HealthCheck(.dependencies, "jq", .passed)
                    : HealthCheck(
                        .dependencies, "jq", .warning, "Space labels in the bar need it",
                        command: "brew install jq"))
        }
        return results
    }

    static func serviceChecks(integrations: Integrations) async -> [HealthCheck] {
        var results: [HealthCheck] = []
        for daemon in Daemon.allCases where Paths.isInstalled(daemon.executableName) {
            guard daemon.isRegistered else {
                results.append(
                    HealthCheck(
                        .services, daemon.displayName, .failed, "Not set to start at login",
                        command: daemon.startCommand))
                continue
            }
            let state = await integrations.state(of: daemon)
            switch state {
            case .running(let pid):
                let ours = daemon.launchdLabel == DaemonAgents.label(daemon)
                let recorded = Startup.lastRun(daemon)
                let seconds =
                    !ours || recorded == pid || !recordedDaemons.contains(daemon)
                    ? nil : await secondsRunning(pid, integrations: integrations)
                results.append(
                    startupCheck(
                        daemon, ours: ours, pid: pid, recorded: recorded, secondsRunning: seconds)
                        ?? HealthCheck(.services, daemon.displayName, .passed, "Running"))
            case .unknown:
                results.append(HealthCheck(.services, daemon.displayName, .unknown, "No answer"))
            case .stopped:
                // A stopped hotkey daemon nearly always has one cause: Secure
                // Keyboard Entry was on when launchd tried to start it.
                if daemon == .skhd, let holder = await integrations.secureInput() {
                    results.append(
                        HealthCheck(.services, daemon.displayName, .failed, holder.explanation))
                } else {
                    results.append(
                        HealthCheck(
                            .services, daemon.displayName, .failed, "Stopped",
                            fix: "Restart it from Advanced", command: daemon.startCommand))
                }
            }
        }
        if Paths.isInstalled("yabai") {
            let registered = await windowSignalsRegistered(integrations: integrations)
            results.append(
                HealthCheck(
                    .services, "Window signals", registered ? .passed : .warning,
                    registered ? "" : "Not registered, so floating rules miss new windows",
                    fix: "Restart yabai from Advanced, which runs its startup file again. "
                        + "If they are still missing, the yabai check says why"))
        }
        return results
    }

    /// Whether the signals `macarchy startup yabai` registers are loaded.
    /// Reading them back is the only way to know they took: a failed
    /// registration leaves no trace. Health and Advanced both use this.
    public static func windowSignalsRegistered(integrations: Integrations) async -> Bool {
        let result = await integrations.execute(Paths.yabai, ["-m", "signal", "--list"])
        guard result.ok,
            let signals = try? JSONSerialization.jsonObject(with: Data(result.stdout.utf8))
                as? [[String: Any]]
        else { return false }
        let labels = Set(signals.compactMap { $0["label"] as? String })
        return labels.isSuperset(of: ["macarchy_window_created", "macarchy_refocus_destroyed"])
    }

    static func configurationChecks(integrations: Integrations) async -> [HealthCheck] {
        let fm = FileManager.default
        var results: [HealthCheck] = []
        if let unmoved = unmovedCheck() { return [unmoved] }
        guard fm.fileExists(atPath: Paths.settings.path) else {
            return [
                HealthCheck(
                    .configuration, "Setup", .failed, "Macarchy has not been set up",
                    fix: "Open Macarchy to set it up", command: setupCommand)
            ]
        }
        results += layoutChecks()
        if let old = await oldConfigurationCheck() { results.append(old) }
        let linked = fm.fileExists(
            atPath: Paths.appLink.appending(path: "Contents/MacOS/macarchy").path)
        results.append(
            HealthCheck(
                .configuration, "App link", linked ? .passed : .failed,
                linked ? "" : "Startup files cannot find Macarchy",
                fix: "Open Macarchy once to repair it"))
        do {
            let settings = try SettingsStore().read()
            results.append(themeCheck(settings))
        } catch {
            results.append(
                HealthCheck(
                    .configuration, "Settings", .failed, error.localizedDescription,
                    fix: "Correct the file, or restore an earlier snapshot from Advanced",
                    file: Paths.settings))
        }
        results += await startupFileChecks(integrations: integrations)
        for daemon in Daemon.allCases where Paths.isInstalled(daemon.executableName) {
            if DaemonAgents.isSetAside(daemon) {
                results.append(
                    HealthCheck(
                        .configuration, "\(daemon.displayName) agent", .failed,
                        "Macarchy's agent did not stay running, so the installer's starts it",
                        fix: "Use Restart all once the cause is fixed",
                        command: "\(Paths.cliInShell) services"))
                continue
            }
            let agent = fm.fileExists(atPath: DaemonAgents.plist(daemon).path)
            let problem =
                agent
                ? startFileProblem(daemon)
                : "Not started by Macarchy, so it misses Macarchy's config"
            results.append(
                HealthCheck(
                    .configuration, "\(daemon.displayName) agent",
                    problem == nil ? .passed : .failed,
                    problem ?? "", fix: "Run setup again", command: setupCommand))
        }
        return results
    }

    /// A broken theme is reported as the theme, not as unreadable settings.
    static func themeCheck(_ settings: SettingsDocument) -> HealthCheck {
        guard let name = settings.currentTheme else {
            return HealthCheck(.configuration, "Theme", .warning, "No theme chosen yet")
        }
        let directory = Paths.themesDirectory.appending(path: name)
        do {
            let theme = try Theme.read(from: directory)
            _ = try theme.wallpaperURL(in: directory, selected: settings.wallpapers[name])
            return HealthCheck(.configuration, "Theme", .passed, name)
        } catch {
            return HealthCheck(
                .configuration, "Theme", .failed, error.localizedDescription,
                fix: "Fix the theme, or apply another from Themes")
        }
    }

    /// After setup each installed tool needs its startup file, and launchd
    /// can only run it while it is executable.
    static func startupFileChecks(integrations: Integrations) async -> [HealthCheck] {
        let fm = FileManager.default
        var results: [HealthCheck] = []
        let tools: [(GeneratedFile, String)] = [
            (StartupConfiguration.yabairc, "yabai"),
            (StartupConfiguration.sketchybarrc, "sketchybar"),
            (StartupConfiguration.bordersrc, "borders")
        ]
        for (file, tool) in tools where Paths.isInstalled(tool) {
            let name = file.url.lastPathComponent
            guard fm.fileExists(atPath: file.url.path) else {
                results.append(
                    HealthCheck(
                        .configuration, name, .failed, "Missing, so \(tool) starts unconfigured",
                        fix: "Run setup again", command: setupCommand))
                continue
            }
            guard fm.isExecutableFile(atPath: file.url.path) else {
                results.append(
                    HealthCheck(
                        .configuration, name, .failed,
                        "Not executable, so it will not run at login",
                        fix: "Run setup again, which repairs it", command: setupCommand))
                continue
            }
            let syntax = await integrations.execute("/bin/bash", ["-n", file.url.path])
            if !syntax.ok {
                // bash echoes the offending line, which may hold a secret, so
                // only its line number is kept.
                let line = syntax.stderr.range(of: "line [0-9]+", options: .regularExpression)
                    .map { String(syntax.stderr[$0]) }
                results.append(
                    HealthCheck(
                        .configuration, name, .failed,
                        "Syntax error" + (line.map { " on \($0)" } ?? ""),
                        fix: "Open \(Paths.display(file.url)) and fix it, or regenerate it",
                        file: file.url))
            } else if file.hasDrifted {
                results.append(
                    HealthCheck(
                        .configuration, name, .warning, "Edited outside its keep region",
                        fix: "Regenerate it from Advanced; edits are snapshotted first"))
            } else {
                results.append(HealthCheck(.configuration, name, .passed))
            }
        }
        return results
    }

    /// The CLI is inside the app bundle and not on PATH, so commands name it in full.
    static let setupCommand = "\(Paths.cliInShell) setup --keep"

    static func optionalChecks() -> [HealthCheck] {
        var results: [HealthCheck] = []
        if Setup.ghosttyWanted {
            let text = (try? String(contentsOf: GhosttyConfig.targetURL, encoding: .utf8)) ?? ""
            results.append(
                GhosttyConfig.hasInclude(text)
                    ? HealthCheck(.optional, "Ghostty theme", .passed)
                    : HealthCheck(
                        .optional, "Ghostty theme", .warning, "Ghostty is not following the theme",
                        fix: "Run setup again to add the include line", command: setupCommand))
        }
        if Paths.isInstalled("yabai") {
            let addition = ScriptingAddition.status()
            results.append(
                HealthCheck(
                    .optional, "yabai scripting addition",
                    addition.isPermitted ? .passed : .unknown,
                    addition.explanation))
        }
        return results
    }
}

extension Daemon {
    /// The executable's file name, for discovery.
    public var executableName: String { rawValue }
}
