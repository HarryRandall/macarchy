import Foundation
import ServiceManagement

/// Stopping the app opening at login, as uninstall does. The app registers
/// itself (`LoginItem` in the app) so the bar's widgets stay up to date; once
/// Macarchy is uninstalled, nothing should start it again.
public enum OpenAtLogin {
    /// Unregisters the app, returning what happened, or nil when it was not
    /// registered or this run leaves login items alone: debug builds,
    /// isolated runs and tests share the installed app's identifier, and the
    /// command only reaches the app's registration from inside the app.
    public static func stop() -> String? {
        #if DEBUG
        return nil
        #else
        guard !DesktopIsolation.isActive, Bundle.main.bundleURL.pathExtension == "app" else {
            return nil
        }
        let service = SMAppService.mainApp
        guard service.status == .enabled || service.status == .requiresApproval else {
            return nil
        }
        do {
            try service.unregister()
            return "Macarchy no longer opens at login"
        } catch {
            return "Macarchy still opens at login: \(error.localizedDescription) Turn it off in "
                + "System Settings, General, Login Items."
        }
        #endif
    }
}
