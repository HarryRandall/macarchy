import AppKit
import Macarchy
import SwiftUI

/// Who is using this Mac, and the setup they have built on it.
///
/// Everything here is read from the system or from the app's own stores —
/// nothing is collected, and nothing leaves the machine.
struct UserPane: View {
    @Environment(AppModel.self) private var model
    @AppStorage("sidebarVisible") private var sidebarVisible = true

    @State private var profile = SystemProfile.current()

    var body: some View {
        SettingsPage("You", subtitle: "Your account, your machine, your setup.") {
            identity
            machine
            setup
            preferences
        }
    }

    // MARK: - Identity

    private var identity: some View {
        HStack(spacing: Metrics.xl) {
            Image(nsImage: profile.picture)
                .resizable()
                .frame(width: 72, height: 72)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Color.cardBorder, lineWidth: 1))
                .shadow(color: .black.opacity(0.25), radius: 10, y: 4)

            VStack(alignment: .leading, spacing: Metrics.xs) {
                Text(profile.fullName).font(.heroTitle)
                Text("@\(profile.userName)")
                    .font(.monoDetail).foregroundStyle(Color.metaText)
                HStack(spacing: Metrics.small) {
                    StatusChip(tone: .good, label: profile.hostName, live: true)
                    StatusChip(tone: .idle, label: profile.shell)
                }
                .padding(.top, 2)
            }

            Spacer(minLength: Metrics.medium)
            HelpTooltip(
                text: "Account and machine details are read locally and are never sent elsewhere.")
        }
        .padding(Metrics.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardSurface, in: card)
        .overlay(card.strokeBorder(Color.cardBorder, lineWidth: 1))
    }

    // MARK: - Machine

    private var machine: some View {
        SettingsCard("This Mac") {
            SettingRow("Model", detail: profile.model) {
                Image(systemName: "laptopcomputer")
                    .font(.system(size: 13)).foregroundStyle(.secondary).frame(width: 20)
            } accessory: {
                EmptyView()
            }
            SettingRow("macOS", detail: profile.system) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 13)).foregroundStyle(.secondary).frame(width: 20)
            } accessory: {
                EmptyView()
            }
            SettingRow("Home folder", detail: profile.home) {
                Image(systemName: "folder")
                    .font(.system(size: 13)).foregroundStyle(.secondary).frame(width: 20)
            } accessory: {
                Button("Reveal") {
                    NSWorkspace.shared.activateFileViewerSelecting([Paths.home])
                }
            }
            SettingRow("Awake for", detail: profile.uptime) {
                Image(systemName: "bolt")
                    .font(.system(size: 13)).foregroundStyle(.secondary).frame(width: 20)
            } accessory: {
                EmptyView()
            }
        }
    }

    // MARK: - Setup

    private var setup: some View {
        SettingsCard("Your setup", help: "What Macarchy is managing on this Mac right now.") {
            SettingRow("Theme", detail: model.themes.current ?? "None applied") {
                Image(systemName: "paintpalette")
                    .font(.system(size: 13)).foregroundStyle(.secondary).frame(width: 20)
            } accessory: {
                Button("Change") {
                    withAnimation(Motion.snappy) { model.selection = .themes }
                }
            }
            SettingRow(
                "Shortcuts",
                detail: "\(model.shortcuts.bindings.count) bound across "
                    + "\(model.shortcuts.allSections.count) groups"
            ) {
                Image(systemName: "command")
                    .font(.system(size: 13)).foregroundStyle(.secondary).frame(width: 20)
            } accessory: {
                Button("Review") {
                    withAnimation(Motion.snappy) { model.selection = .shortcuts }
                }
            }
            SettingRow(
                "Floating apps",
                detail: model.rules.rules.isEmpty
                    ? "Every app is tiled" : "\(model.rules.rules.count) apps left untiled"
            ) {
                Image(systemName: "flag")
                    .font(.system(size: 13)).foregroundStyle(.secondary).frame(width: 20)
            } accessory: {
                Button("Review") {
                    withAnimation(Motion.snappy) { model.selection = .rules }
                }
            }
        }
    }

    // MARK: - Preferences

    private var preferences: some View {
        SettingsCard("Preferences", help: "How this window behaves. Stored on this Mac only.") {
            SettingRow(
                "Sidebar", help: "Show the section names beside their icons."
            ) {
                Image(systemName: "sidebar.leading")
                    .font(.system(size: 13)).foregroundStyle(.secondary).frame(width: 20)
            } accessory: {
                Toggle("Sidebar", isOn: $sidebarVisible.animation(Motion.snappy))
                    .labelsHidden().toggleStyle(.switch)
            }
            SettingRow(
                "Interface accent",
                help: "Uses the accent colour of your applied theme."
            ) {
                Image(systemName: "drop")
                    .font(.system(size: 13)).foregroundStyle(.secondary).frame(width: 20)
            } accessory: {
                Circle()
                    .fill(model.interfaceAccent)
                    .frame(width: 18, height: 18)
                    .overlay(Circle().strokeBorder(Color.cardBorder, lineWidth: 1))
            }
        }
    }

    private var card: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.radiusCard, style: .continuous)
    }
}

/// The handful of system facts the page shows, read once when it opens.
struct SystemProfile {
    var fullName: String
    var userName: String
    var hostName: String
    var shell: String
    var model: String
    var system: String
    var home: String
    var uptime: String
    var picture: NSImage

    static func current() -> SystemProfile {
        let info = ProcessInfo.processInfo
        let version = info.operatingSystemVersion
        return SystemProfile(
            fullName: NSFullUserName(),
            userName: NSUserName(),
            hostName: Host.current().localizedName ?? info.hostName,
            shell: (ProcessInfo.processInfo.environment["SHELL"] as NSString?)?
                .lastPathComponent ?? "sh",
            model: hardwareModel(),
            system:
                "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)",
            home: Paths.home.path,
            uptime: format(info.systemUptime),
            picture: NSImage(named: NSImage.userName) ?? NSImage())
    }

    /// `hw.model` is the only identifier available without extra entitlements.
    private static func hardwareModel() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        guard size > 0 else { return "Mac" }
        var bytes = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &bytes, &size, nil, 0)
        let value = String(cString: bytes)
        return value.isEmpty ? "Mac" : value
    }

    private static func format(_ seconds: TimeInterval) -> String {
        let style = DateComponentsFormatter()
        style.allowedUnits = [.day, .hour, .minute]
        style.unitsStyle = .abbreviated
        style.maximumUnitCount = 2
        return style.string(from: seconds) ?? "just started"
    }
}
