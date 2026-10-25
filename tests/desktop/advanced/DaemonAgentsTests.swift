import Foundation
import Testing

@testable import App
@testable import Macarchy

extension WebInterfaceTests {
    /// Uses the parent's isolated environment without creating a web view.
    @MainActor
    @Suite("Daemon agents")
    struct DaemonAgentsTests {
        /// The upgrade case: the old BordersService used Macarchy's label, so
        /// its job is still loaded with the old program when setup rewrites
        /// the agent. A kickstart alone would rerun the old program.
        @Test("a loaded job whose agent changed on disk is reloaded before it starts")
        func reloadsChangedJob() async throws {
            try await withHarness(tools: ["borders"]) { harness in
                let launchd = await FakeLaunchd.attached(to: harness)
                let ours = DaemonAgents.label(.borders)
                launchd.load(
                    ours,
                    arguments: [harness.home.appending(path: ".config/borders/bordersrc").path])
                try install(.borders)

                let result = await DaemonAgents.start(.borders, integrations: harness.model.backend)

                #expect(result.ok, "\(result.stderr)")
                let calls = launchd.calls(for: ours)
                let bootout = try #require(calls.firstIndex(of: "bootout"))
                #expect(bootout < (calls.firstIndex(of: "bootstrap") ?? -1))
                #expect(calls.last == "kickstart")
                #expect(
                    launchd.definition(of: ours)
                        == DaemonAgents.definition(at: DaemonAgents.plist(.borders)))
                #expect(launchd.isRunning(ours))
            }
        }

        @Test("a loaded job that matches its agent is only restarted")
        func restartsMatchingJob() async throws {
            try await withHarness(tools: ["yabai"]) { harness in
                let launchd = await FakeLaunchd.attached(to: harness)
                try install(.yabai)
                launchd.load(DaemonAgents.plist(.yabai))

                let result = await DaemonAgents.start(.yabai, integrations: harness.model.backend)

                #expect(result.ok, "\(result.stderr)")
                let calls = launchd.calls(for: DaemonAgents.label(.yabai))
                #expect(!calls.contains("bootout") && !calls.contains("bootstrap"))
                #expect(calls.contains("kickstart"))
            }
        }

        /// Secure Input refuses skhd. The installer's job was running, so it
        /// gets the daemon back, and Macarchy's agent must leave
        /// `LaunchAgents`, or both would load at the next login.
        @Test(
            "a refused start gives the daemon back to a working installer agent and sets ours aside"
        )
        func setsAsideForWorkingInstaller() async throws {
            try await withHarness(tools: ["skhd"]) { harness in
                let launchd = await FakeLaunchd.attached(to: harness)
                let installer = try harness.installerAgent(
                    "com.asmvik.skhd", arguments: ["/opt/homebrew/bin/skhd"])
                launchd.load(installer)
                try install(.skhd)
                await harness.desktop.answer("ioreg") { _ in
                    .success("\"kCGSSessionSecureInputPID\"=82230")
                }
                await harness.desktop.answer("ps") { _ in
                    .success("/Applications/Firefox.app/Contents/MacOS/firefox")
                }

                let result = await DaemonAgents.start(.skhd, integrations: harness.model.backend)

                #expect(!result.ok)
                #expect(result.stderr.contains("firefox"))
                #expect(result.stderr.contains("runs from com.asmvik.skhd again"))
                #expect(result.stderr.contains("set aside"))
                #expect(launchd.isRunning("com.asmvik.skhd"))
                #expect(!launchd.isLoaded(DaemonAgents.label(.skhd)))
                let fm = FileManager.default
                #expect(fm.fileExists(atPath: installer.path))
                #expect(!fm.fileExists(atPath: DaemonAgents.plist(.skhd).path))
                #expect(DaemonAgents.isSetAside(.skhd))
                #expect(DaemonAgents.isInstalled(.skhd))
                // The installer's job is the one a restart now reaches.
                #expect(Daemon.skhd.launchdLabel == "com.asmvik.skhd")

                // Once Secure Input is off, Restart all takes over again.
                await harness.desktop.answer("ioreg") { _ in .success("") }
                let retried = await Setup.startService(.skhd, integrations: harness.model.backend)
                #expect(retried.ok, "\(retried.stderr)")
                #expect(fm.fileExists(atPath: DaemonAgents.plist(.skhd).path))
                #expect(!DaemonAgents.isSetAside(.skhd))
                #expect(!fm.fileExists(atPath: installer.path))
                #expect(!launchd.isLoaded("com.asmvik.skhd"))
                #expect(launchd.isRunning(DaemonAgents.label(.skhd)))
            }
        }

        /// With nothing that was working to go back to, booting Macarchy's
        /// job out would leave the daemon stopped until the next login.
        @Test("a failed start with no working installer agent keeps ours loaded and alone")
        func keepsOursWithoutWorkingInstaller() async throws {
            try await withHarness(tools: ["borders"]) { harness in
                let launchd = await FakeLaunchd.attached(to: harness)
                let ours = DaemonAgents.label(.borders)
                // An installer's agent on disk that was not running.
                let installer = try harness.installerAgent(
                    "homebrew.mxcl.borders", arguments: ["/opt/homebrew/bin/borders"])
                launchd.load(
                    ours,
                    arguments: [harness.home.appending(path: ".config/borders/bordersrc").path])
                launchd.crashing.insert(ours)
                try install(.borders)

                let result = await DaemonAgents.start(.borders, integrations: harness.model.backend)

                #expect(!result.ok)
                #expect(result.stderr.contains("did not stay running"))
                #expect(result.stderr.contains("launchd keeps trying"))
                // Reloaded with the new agent, and not booted out after the failure.
                let calls = launchd.calls(for: ours)
                let bootstrap = try #require(calls.lastIndex(of: "bootstrap"))
                #expect(calls[bootstrap...].contains("kickstart"))
                #expect(!calls[bootstrap...].contains("bootout"))
                #expect(launchd.isLoaded(ours))
                #expect(
                    launchd.definition(of: ours)
                        == DaemonAgents.definition(at: DaemonAgents.plist(.borders)))
                #expect(
                    launchd.calls(for: "homebrew.mxcl.borders").filter { $0 == "bootstrap" }.isEmpty
                )
                let fm = FileManager.default
                #expect(fm.fileExists(atPath: DaemonAgents.plist(.borders).path))
                #expect(!fm.fileExists(atPath: installer.path))
                #expect(!DaemonAgents.isSetAside(.borders))
            }
        }

        @Test("setup writing the agent again clears a set-aside copy")
        func installClearsSetAside() async throws {
            try await withHarness(tools: ["yabai"]) { _ in
                try install(.yabai)
                let aside = DaemonAgents.asidePlist(.yabai)
                try FileManager.default.createDirectory(
                    at: aside.deletingLastPathComponent(), withIntermediateDirectories: true)
                try FileManager.default.moveItem(at: DaemonAgents.plist(.yabai), to: aside)
                #expect(DaemonAgents.isSetAside(.yabai))
                try install(.yabai)
                #expect(!DaemonAgents.isSetAside(.yabai))
                #expect(!FileManager.default.fileExists(atPath: aside.path))
            }
        }
    }
}

private func install(_ daemon: Daemon) throws {
    var report: [String] = []
    try DaemonAgents.install(daemon, backups: Backups(), report: &report)
}

extension Harness {
    /// Writes an installer's agent into the home's `LaunchAgents`.
    fileprivate func installerAgent(_ label: String, arguments: [String]) throws -> URL {
        let url = home.appending(path: "Library/LaunchAgents/\(label).plist")
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let plist: [String: Any] = [
            "Label": label, "ProgramArguments": arguments, "RunAtLoad": true, "KeepAlive": true
        ]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            .write(to: url)
        return url
    }
}

/// A launchd for one test: jobs load from the agent files they are
/// bootstrapped with and keep that definition until booted out, as the real
/// one does, and `print` describes them in launchctl's own layout.
private final class FakeLaunchd: @unchecked Sendable {
    private struct Job {
        var arguments: [String]
        var environment: [String: String]
        var standardOut: String?
        var standardError: String?
        var running: Bool
    }

    private let lock = NSLock()
    private var jobs: [String: Job] = [:]
    private var log: [(label: String, verb: String)] = []
    /// Labels whose program exits as soon as it starts.
    var crashing: Set<String> {
        get { lock.withLock { crashingLabels } }
        set { lock.withLock { crashingLabels = newValue } }
    }
    private var crashingLabels: Set<String> = []

    /// Answers every launchctl call the harness's fake desktop receives.
    @MainActor
    static func attached(to harness: Harness) async -> FakeLaunchd {
        let launchd = FakeLaunchd()
        await harness.desktop.answer("launchctl") { launchd.reply($0) }
        return launchd
    }

    func load(_ label: String, arguments: [String]) {
        lock.withLock {
            jobs[label] = Job(
                arguments: arguments, environment: [:], standardOut: nil, standardError: nil,
                running: true)
        }
    }

    func load(_ agent: URL) { _ = bootstrap(agent.path, record: false) }

    func isLoaded(_ label: String) -> Bool { lock.withLock { jobs[label] != nil } }
    func isRunning(_ label: String) -> Bool { lock.withLock { jobs[label]?.running == true } }

    func definition(of label: String) -> LoadedJob.Definition? {
        lock.withLock {
            jobs[label].map {
                LoadedJob.Definition(
                    arguments: $0.arguments, path: $0.environment["PATH"],
                    standardOut: $0.standardOut, standardError: $0.standardError)
            }
        }
    }

    /// The verbs run against `label`, in order, leaving out `print`.
    func calls(for label: String) -> [String] {
        lock.withLock { log.filter { $0.label == label && $0.verb != "print" }.map(\.verb) }
    }

    private func reply(_ arguments: [String]) -> FakeDesktop.Reply? {
        guard let verb = arguments.first, let last = arguments.last else { return nil }
        if verb == "bootstrap" { return bootstrap(last, record: true) }
        // Every other verb names a service target, `gui/<uid>/<label>`.
        let label = String(last.split(separator: "/").last ?? "")
        lock.withLock { log.append((label, verb)) }
        switch verb {
        case "print": return describe(label)
        case "bootout":
            return lock.withLock { jobs.removeValue(forKey: label) } == nil
                ? .failure("Boot-out failed: 3: No such process", status: 3) : .success()
        case "kickstart":
            return lock.withLock {
                guard jobs[label] != nil else {
                    return .failure("Could not find service", status: 113)
                }
                jobs[label]?.running = !crashingLabels.contains(label)
                return .success()
            }
        default: return .failure("Not available in tests.", status: 64)
        }
    }

    private func bootstrap(_ path: String, record: Bool) -> FakeDesktop.Reply {
        guard let data = FileManager.default.contents(atPath: path),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil)
                as? [String: Any],
            let label = plist["Label"] as? String,
            let arguments = plist["ProgramArguments"] as? [String]
        else { return .failure("Bootstrap failed: 5: Input/output error", status: 5) }
        if record { lock.withLock { log.append((label, "bootstrap")) } }
        return lock.withLock {
            guard jobs[label] == nil else {
                return .failure("Bootstrap failed: 5: Input/output error", status: 5)
            }
            jobs[label] = Job(
                arguments: arguments,
                environment: plist["EnvironmentVariables"] as? [String: String] ?? [:],
                standardOut: plist["StandardOutPath"] as? String,
                standardError: plist["StandardErrorPath"] as? String,
                running: !crashingLabels.contains(label))
            return .success()
        }
    }

    private func describe(_ label: String) -> FakeDesktop.Reply {
        lock.withLock {
            guard let job = jobs[label] else {
                return .failure("Could not find service \"\(label)\" in domain", status: 113)
            }
            var lines = [
                "gui/501/\(label) = {", "\tactive count = 1",
                "\tstate = \(job.running ? "running" : "not running")",
                "\tprogram = \(job.arguments.first ?? "")", "\targuments = {"
            ]
            lines += job.arguments.map { "\t\t\($0)" } + ["\t}"]
            if let out = job.standardOut { lines.append("\tstdout path = \(out)") }
            if let error = job.standardError { lines.append("\tstderr path = \(error)") }
            lines += ["\tinherited environment = {", "\t\tPATH => /usr/bin:/bin", "\t}"]
            lines += ["\tenvironment = {"]
            lines += job.environment.sorted { $0.key < $1.key }.map {
                "\t\t\($0.key) => \($0.value)"
            }
            lines += ["\t\tXPC_SERVICE_NAME => \(label)", "\t}"]
            if job.running { lines.append("\tpid = 4242") }
            lines.append("}")
            return .success(lines.joined(separator: "\n"))
        }
    }
}
