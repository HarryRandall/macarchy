import Foundation

/// Installs and removes tools with Homebrew, one at a time, saying what it is
/// doing as it goes. Setup installs the daemons a person chose with it; any
/// other page can install its own packages the same way, such as
/// `Package.neovim` or `Package.ghostty`.
///
/// What Macarchy installed itself is recorded in `state/installed-tools.json`,
/// so uninstall can offer to remove exactly those and never a tool that was
/// there before.
public struct ToolInstaller: Sendable {
    /// One thing Homebrew installs.
    public struct Package: Sendable, Hashable, Codable, Identifiable {
        /// Stable and unique, such as a daemon's name; the record uses it.
        public let id: String
        public let name: String
        /// What `brew install` is given, such as `asmvik/formulae/yabai`. A
        /// tap in the name is added by Homebrew itself.
        public let formula: String
        public let cask: Bool
        /// The executable a formula provides, or the app a cask installs,
        /// which says whether the package is present.
        public let provides: String

        public init(id: String, name: String, formula: String, cask: Bool = false, provides: String)
        {
            self.id = id
            self.name = name
            self.formula = formula
            self.cask = cask
            self.provides = provides
        }

        public var isInstalled: Bool {
            cask ? Paths.hasApplication(provides) : Paths.isInstalled(provides)
        }

        var installArguments: [String] { ["install"] + (cask ? ["--cask"] : []) + [formula] }
        var uninstallArguments: [String] { ["uninstall"] + (cask ? ["--cask"] : []) + [formula] }

        /// The command a person could run instead, for help text and Doctor.
        public var command: String { (["brew"] + installArguments).joined(separator: " ") }

        public static let neovim = Package(
            id: "neovim", name: "Neovim", formula: "neovim", provides: "nvim")
        public static let ghostty = Package(
            id: "ghostty", name: "Ghostty", formula: "ghostty", cask: true, provides: "Ghostty")
    }

    /// What is happening to one package, in order: started, any output, then
    /// one of the endings.
    public enum Progress: Sendable, Equatable {
        case started(Package)
        /// A line of Homebrew's output.
        case output(Package, String)
        case finished(Package)
        /// It did not happen, and why.
        case failed(Package, String)
    }

    /// What a run did, for the report.
    public struct Report: Sendable, Equatable {
        /// Installed or removed by this run.
        public var changed: [Package] = []
        /// Already as asked, so left alone.
        public var unchanged: [Package] = []
        public var failures: [Failure] = []

        public struct Failure: Sendable, Equatable {
            public let package: Package
            public let reason: String
        }
    }

    /// Runs Homebrew, passing each line of output on as it arrives.
    public typealias Run =
        @Sendable (
            _ executable: String, _ arguments: [String],
            _ line: @escaping @Sendable (String) -> Void
        )
        async -> CommandResult

    private let run: Run
    private let record: URL

    /// `run` replaces Homebrew in tests, and `record` the file the
    /// installed packages are written to.
    public init(run: Run? = nil, record: URL? = nil) {
        self.run =
            run ?? { executable, arguments, line in
                await CommandRunner.stream(
                    executable, arguments, environment: ToolInstaller.environment, line: line)
            }
        self.record = record ?? Paths.stateDirectory.appending(path: "installed-tools.json")
    }

    /// Homebrew's `brew`, found like any other tool, or nil when Homebrew is
    /// not installed.
    public static var homebrew: String? {
        Paths.isInstalled("brew") ? Paths.executable("brew") : nil
    }

    /// Homebrew asks nothing and prints no hints, and finds its own tools
    /// even when the app was opened from Finder with a minimal PATH.
    static var environment: [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let folders = [
            Paths.homebrewFolder, "/usr/bin", "/bin", "/usr/sbin", "/sbin"
        ].compactMap { $0 }
        environment["PATH"] = (folders + [environment["PATH"]].compactMap { $0 })
            .joined(separator: ":")
        environment["HOMEBREW_NO_ENV_HINTS"] = "1"
        environment["NONINTERACTIVE"] = "1"
        return environment
    }

    // MARK: - Installing

    /// Installs each package that is missing, in order, and records the
    /// ones it installed. One that fails is reported and the rest still run.
    public func install(
        _ packages: [Package], progress: @escaping @Sendable (Progress) -> Void = { _ in }
    ) async -> Report {
        var report = Report()
        for package in packages {
            guard !package.isInstalled else {
                report.unchanged.append(package)
                continue
            }
            guard let brew = Self.homebrew else {
                fail(package, Self.homebrewMissing, report: &report, progress: progress)
                continue
            }
            progress(.started(package))
            let result = await run(brew, package.installArguments) {
                progress(.output(package, $0))
            }
            if let reason = Self.problem(result, package: package, expectInstalled: true) {
                fail(package, reason, report: &report, progress: progress)
                continue
            }
            do {
                try remember(package)
            } catch {
                // It is installed, so say so; only removing it later is affected.
                progress(
                    .output(
                        package,
                        "Installed, but not recorded, so uninstall will not offer to remove it: "
                            + error.localizedDescription))
            }
            report.changed.append(package)
            progress(.finished(package))
        }
        return report
    }

    /// Removes packages Macarchy installed. Anything not in its record is
    /// refused, so a tool that was there before Macarchy is never removed.
    public func uninstall(
        _ packages: [Package], progress: @escaping @Sendable (Progress) -> Void = { _ in }
    ) async -> Report {
        var report = Report()
        let recorded = Set((try? installed()) ?? [])
        for package in packages {
            guard recorded.contains(package) else {
                fail(
                    package, "\(package.name) was not installed by Macarchy, so it was left alone",
                    report: &report, progress: progress)
                continue
            }
            guard package.isInstalled else {
                try? forget(package)
                report.unchanged.append(package)
                continue
            }
            guard let brew = Self.homebrew else {
                fail(package, Self.homebrewMissing, report: &report, progress: progress)
                continue
            }
            progress(.started(package))
            let result = await run(brew, package.uninstallArguments) {
                progress(.output(package, $0))
            }
            if let reason = Self.problem(result, package: package, expectInstalled: false) {
                fail(package, reason, report: &report, progress: progress)
                continue
            }
            try? forget(package)
            report.changed.append(package)
            progress(.finished(package))
        }
        return report
    }

    private func fail(
        _ package: Package, _ reason: String, report: inout Report,
        progress: @Sendable (Progress) -> Void
    ) {
        report.failures.append(.init(package: package, reason: reason))
        progress(.failed(package, reason))
    }

    static let homebrewMissing =
        "Homebrew is not installed. Install it from brew.sh, then try again"

    /// Why a run did not leave the package as asked, or nil when it did.
    /// Homebrew can exit cleanly without installing, so the package is
    /// looked for afterwards as well.
    private static func problem(
        _ result: CommandResult, package: Package, expectInstalled: Bool
    ) -> String? {
        if let skipped = result.skipped.first { return skipped }
        guard result.ok else { return result.stderr }
        guard package.isInstalled != expectInstalled else { return nil }
        return expectInstalled
            ? "Homebrew finished, but \(package.provides) is still missing"
            : "Homebrew finished, but \(package.provides) is still there"
    }

    // MARK: - Record

    /// The packages Macarchy installed, whether or not they are still there.
    public func installed() throws -> [Package] {
        guard FileManager.default.fileExists(atPath: record.path) else { return [] }
        return try JSONFile.decode([Package].self, from: record)
    }

    /// The packages Macarchy installed that are still there, which uninstall
    /// may offer to remove. Unreadable records offer nothing.
    public func removable() -> [Package] {
        ((try? installed()) ?? []).filter(\.isInstalled)
    }

    private func remember(_ package: Package) throws {
        var packages = try installed()
        guard !packages.contains(package) else { return }
        packages.append(package)
        try save(packages)
    }

    private func forget(_ package: Package) throws {
        try save(try installed().filter { $0 != package })
    }

    private func save(_ packages: [Package]) throws {
        try FileManager.default.createDirectory(
            at: record.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(packages).write(to: record, options: .atomic)
    }

    // MARK: - Homebrew itself

    /// The official installer from brew.sh, as a file Terminal can open. It
    /// asks for the person's password, so it must run where they can answer;
    /// Macarchy never runs it itself.
    public static func homebrewInstaller() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(
            path: "macarchy-install-homebrew.command")
        let script = """
            #!/bin/bash
            # Written by Macarchy: installs Homebrew the way https://brew.sh describes.
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            status=$?
            echo
            if [ "$status" -eq 0 ]; then
              echo "Homebrew is installed. Return to Macarchy and choose Check again."
            else
              echo "The Homebrew installer stopped with status $status."
            fi

            """
        try script.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }
}

extension Paths {
    /// The folder `brew` was found in, or nil without Homebrew.
    static var homebrewFolder: String? {
        ToolInstaller.homebrew.map { URL(fileURLWithPath: $0).deletingLastPathComponent().path }
    }
}

extension Daemon {
    /// How Homebrew installs this daemon.
    public var package: ToolInstaller.Package {
        let formula =
            switch self {
            case .yabai: "asmvik/formulae/yabai"
            case .skhd: "asmvik/formulae/skhd"
            case .sketchybar: "FelixKratz/formulae/sketchybar"
            case .borders: "FelixKratz/formulae/borders"
            }
        return ToolInstaller.Package(
            id: rawValue, name: displayName, formula: formula, provides: executableName)
    }
}
