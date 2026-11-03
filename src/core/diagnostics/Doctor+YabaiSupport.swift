import Foundation

extension Doctor {
    /// The newest yabai release Macarchy knows of, and the newest macOS it
    /// supports. yabai matches the macOS major version exactly, so on a newer
    /// one it takes none of its modern paths: it stops hearing the window
    /// server say a window closed and stops watching Mission Control. Closed or
    /// moved windows can then leave empty space, and focus is lost more often.
    static let newestKnownYabai = [7, 1, 25]
    static let newestMacOSForKnownYabai = 26

    static func yabaiSupportCheck(integrations: Integrations) async -> HealthCheck? {
        guard Setup.chosenTools.contains(.yabai), Paths.isInstalled(Daemon.yabai.executableName)
        else { return nil }
        let result = await integrations.execute(Paths.yabai, ["--version"])
        guard result.ok else { return nil }
        return yabaiSupport(
            version: result.stdout,
            macOS: ProcessInfo.processInfo.operatingSystemVersion.majorVersion)
    }

    /// A warning when this yabai predates the running macOS. A version newer
    /// than the newest known release, or one that cannot be read, is assumed
    /// to support it rather than warned about on a guess.
    static func yabaiSupport(version: String, macOS: Int) -> HealthCheck? {
        let fields = version.trimmingCharacters(in: .whitespacesAndNewlines)
            .drop { !$0.isNumber }.split(separator: ".")
        let parts = fields.compactMap { Int($0) }
        guard macOS > newestMacOSForKnownYabai, parts.count == 3, fields.count == 3,
            !newestKnownYabai.lexicographicallyPrecedes(parts)
        else { return nil }
        return HealthCheck(
            .dependencies, "yabai on macOS \(macOS)", .warning,
            "yabai \(parts.map(String.init).joined(separator: ".")) supports macOS "
                + "\(newestMacOSForKnownYabai) and earlier, so it can miss windows closing and "
                + "Mission Control, leaving empty space and nothing focused",
            fix: "Update yabai once a release supports macOS \(macOS)")
    }
}
