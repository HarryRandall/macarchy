import Foundation

/// The CLI tells the running app about widget clicks, Space changes and the
/// switcher through distributed notifications, which every running copy
/// receives. Each notice names the home it was sent from, so an isolated copy
/// and the installed one act only on their own: a development build's widgets
/// work, and its clicks never reach the installed app.
public enum AppNotice {
    static let homeKey = "home"

    public static func post(_ name: Notification.Name, _ userInfo: [AnyHashable: Any] = [:]) {
        // Tests run the CLI's code in-process; no app should hear them.
        guard !DesktopIsolation.isTestProcess else { return }
        var info = userInfo
        info[homeKey] = home
        DistributedNotificationCenter.default().postNotificationName(
            name, object: nil, userInfo: info, deliverImmediately: true)
    }

    /// Whether a notice was meant for this copy.
    public static func isForThisCopy(_ notification: Notification) -> Bool {
        accepts(notification.userInfo?[homeKey] as? String, home: home, isolated: Paths.isolated)
    }

    /// A notice without a home comes from an older CLI, which only ever
    /// served the real home, so only a copy that is not isolated takes it.
    static func accepts(_ sender: String?, home: String, isolated: Bool) -> Bool {
        guard let sender else { return !isolated }
        return sender == home
    }

    static var home: String {
        Paths.home.standardizedFileURL.resolvingSymlinksInPath().path
    }
}
