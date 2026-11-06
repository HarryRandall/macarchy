import Foundation

/// Service actions share the Secure Input hand-off across both interfaces.
@MainActor
public struct DesktopServices {
    public var integrations: Integrations
    public var deactivate: @MainActor () -> Void
    public var activate: @MainActor () -> Void

    public init(
        integrations: Integrations = Integrations(),
        deactivate: @escaping @MainActor () -> Void = {},
        activate: @escaping @MainActor () -> Void = {}
    ) {
        self.integrations = integrations
        self.deactivate = deactivate
        self.activate = activate
    }

    public func restart(_ daemon: Daemon) async -> CommandResult {
        let yielded = daemon == .skhd ? await yieldSecureInput() : false
        defer { if yielded { activate() } }
        return await integrations.restart(daemon)
    }

    /// Starts a daemon as `macarchy services` does, registering one that has
    /// no LaunchAgent yet, with the same Secure Input hand-off as `restart`.
    public func start(_ daemon: Daemon) async -> CommandResult {
        let yielded = daemon == .skhd ? await yieldSecureInput() : false
        defer { if yielded { activate() } }
        return await Setup.startService(daemon, integrations: integrations)
    }

    public func stop(_ daemon: Daemon) async -> CommandResult {
        await integrations.stop(daemon)
    }

    private func yieldSecureInput() async -> Bool {
        guard let holder = await integrations.secureInput(), holder.isThisProcess else {
            return false
        }
        deactivate()
        for _ in 0..<12 {
            try? await Task.sleep(for: .milliseconds(80))
            if await integrations.secureInput() == nil { break }
        }
        return true
    }
}
