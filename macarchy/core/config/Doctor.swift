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
    /// A command or action that fixes it, when there is one.
    public let fix: String?

    public var id: String { group.rawValue + "/" + title }

    public init(
        _ group: Group, _ title: String, _ status: Status, _ detail: String = "",
        fix: String? = nil
    ) {
        self.group = group
        self.title = title
        self.status = status
        self.detail = detail
        self.fix = fix
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
                if let fix = check.fix, check.status != .passed { lines.append("       \(fix)") }
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
                    fix: daemon.installCommand)
        }
        // The bundled bar's Space labels read yabai's JSON through jq.
        if (try? SettingsStore().read().bundledBar) ?? true != false {
            results.append(
                Paths.isInstalled("jq")
                    ? HealthCheck(.dependencies, "jq", .passed)
                    : HealthCheck(
                        .dependencies, "jq", .warning, "Space labels in the bar need it",
                        fix: "brew install jq"))
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
                        fix: daemon.startCommand))
                continue
            }
            let state = await integrations.state(of: daemon)
            switch state {
            case .running:
                results.append(HealthCheck(.services, daemon.displayName, .passed, "Running"))
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
                            fix: "Restart it from Advanced, or run: \(daemon.startCommand)"))
                }
            }
        }
        if Paths.isInstalled("yabai") {
            let signals = await integrations.execute(Paths.yabai, ["-m", "signal", "--list"])
            let registered = signals.ok && signals.stdout.contains("macarchy_window_created")
            results.append(
                HealthCheck(
                    .services, "Window signals", registered ? .passed : .warning,
                    registered ? "" : "Floating rules apply to new windows after a restart",
                    fix: "Restart yabai"))
        }
        return results
    }

    static func configurationChecks(integrations: Integrations) async -> [HealthCheck] {
        let fm = FileManager.default
        var results: [HealthCheck] = []
        guard fm.fileExists(atPath: Paths.settings.path) else {
            return [
                HealthCheck(
                    .configuration, "Setup", .failed, "Macarchy has not been set up",
                    fix: "Open Macarchy, or run: macarchy setup")
            ]
        }
        let linked = fm.fileExists(
            atPath: Paths.appLink.appending(path: "Contents/MacOS/macarchy").path)
        results.append(
            HealthCheck(
                .configuration, "App link", linked ? .passed : .failed,
                linked ? "" : "Startup files cannot find Macarchy",
                fix: "Open Macarchy once to repair it"))
        do {
            let settings = try SettingsStore().read()
            if let name = settings.currentTheme {
                let directory = Paths.themesDirectory.appending(path: name)
                let theme = try Theme.read(from: directory)
                _ = try theme.wallpaperURL(in: directory, selected: settings.wallpapers[name])
                results.append(HealthCheck(.configuration, "Theme", .passed, name))
            } else {
                results.append(
                    HealthCheck(.configuration, "Theme", .warning, "No theme chosen yet"))
            }
        } catch {
            results.append(
                HealthCheck(.configuration, "Settings", .failed, error.localizedDescription))
        }
        for file in StartupConfiguration.all where fm.fileExists(atPath: file.url.path) {
            let name = file.url.lastPathComponent
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
                        fix: "Open \(Paths.display(file.url)) and fix it, or regenerate it"))
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

    static func optionalChecks() -> [HealthCheck] {
        var results: [HealthCheck] = []
        if Setup.ghosttyWanted {
            let text = (try? String(contentsOf: GhosttyConfig.targetURL, encoding: .utf8)) ?? ""
            results.append(
                GhosttyConfig.hasInclude(text)
                    ? HealthCheck(.optional, "Ghostty theme", .passed)
                    : HealthCheck(
                        .optional, "Ghostty theme", .warning, "Ghostty is not following the theme",
                        fix: "Run setup again to add the include line"))
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
