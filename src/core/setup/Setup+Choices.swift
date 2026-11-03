import Foundation

/// Which tools setup configures, and how each one starts.
extension Setup {
    /// What setup does: which tools it configures, and for each one with a
    /// config of its own, whether to start from that config.
    public struct Choices: Sendable, Equatable {
        /// The tools to configure and start. The others are left alone: no
        /// startup file, agent or service is written or started for them.
        public var tools: Set<Daemon>
        /// How each tool starts; `keep` for any not given.
        public var existing: [Daemon: Existing]
        /// Ids of `Setup.extras` to install if missing. They need no files
        /// or services, so nothing else about setup changes for them.
        public var extras: Set<String> = []

        public init(
            tools: Set<Daemon> = Set(Daemon.allCases), existing: [Daemon: Existing] = [:],
            extras: Set<String> = []
        ) {
            self.tools = tools
            self.existing = existing
            self.extras = extras
        }

        /// Every tool starting the same way, as `--keep` or `--replace` alone do.
        public init(tools: Set<Daemon> = Set(Daemon.allCases), all: Existing) {
            self.init(
                tools: tools,
                existing: Dictionary(uniqueKeysWithValues: Daemon.allCases.map { ($0, all) }))
        }

        public func existing(_ daemon: Daemon) -> Existing { existing[daemon] ?? .keep }

        /// The chosen tools in their usual order, as settings saves them.
        var ordered: [Daemon] { Daemon.allCases.filter(tools.contains) }
    }

    /// Apps setup can install that Macarchy uses when they are there, with
    /// nothing to configure.
    public static let extras: [ToolInstaller.Package] = [InstantSpaceSwitcher.package]

    /// The tools the last setup was told to configure. Every tool before
    /// setup has asked, as earlier versions configured them all, and when
    /// settings cannot be read, which Doctor reports.
    public static var chosenTools: Set<Daemon> {
        guard let names = (try? SettingsStore().read())?.tools else { return Set(Daemon.allCases) }
        return Set(names.compactMap(Daemon.init(rawValue:)))
    }

    /// The person's own config `daemon` can start from with `keep`, until
    /// Macarchy's copy exists. Only yabai and skhd: the bar is always
    /// Macarchy's widgets, and borders is configured from settings.
    public static func ownConfig(_ daemon: Daemon) -> URL? {
        let source: URL?
        switch daemon {
        case .yabai:
            guard !isGenerated(StartupConfiguration.yabairc.url) else { return nil }
            source = yabaiSource.flatMap { isGenerated($0) ? nil : $0 }
        case .skhd:
            guard !FileManager.default.fileExists(atPath: skhdrc.path) else { return nil }
            source = skhdSource
        case .sketchybar, .borders:
            return nil
        }
        return source.flatMap { adoptable($0) == nil ? nil : $0 }
    }
}

extension Daemon {
    /// Installed and chosen in setup, so Macarchy configures, starts and
    /// checks it. A tool left out of setup is left alone everywhere.
    public var isManaged: Bool {
        Paths.isInstalled(executableName) && Setup.chosenTools.contains(self)
    }
}
