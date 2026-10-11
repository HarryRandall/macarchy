import Carbon.HIToolbox
import Foundation
import OSLog

/// A system-wide shortcut registered with the Carbon event manager.
///
/// Registered hotkeys need no Accessibility permission, unlike an event tap,
/// and fire while another app is frontmost. The system keeps its own
/// shortcuts first: if one already owns the combination, registration fails
/// and `isRegistered` stays false.
@MainActor
final class HotKey {
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: @MainActor () -> Void
    private(set) var isRegistered = false

    /// One identifier is enough while the app owns a single hotkey.
    private static let signature = OSType(0x4D_43_48_59)  // "MCHY"
    private static var actions: [UInt32: @MainActor () -> Void] = [:]

    init(keyCode: Int, modifiers: Int, action: @escaping @MainActor () -> Void) {
        self.action = action
        let id = UInt32(Self.actions.count + 1)
        Self.actions[id] = action

        var type = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ in
                var hotKey = EventHotKeyID()
                GetEventParameter(
                    event, EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKey)
                let id = hotKey.id
                Logger(subsystem: "io.github.harryrandall.macarchy", category: "switcher")
                    .notice("hotkey \(id, privacy: .public) pressed")
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { HotKey.actions[id]?() }
                }
                return noErr
            }, 1, &type, nil, &handler)

        let status = RegisterEventHotKey(
            UInt32(keyCode), UInt32(modifiers), EventHotKeyID(signature: Self.signature, id: id),
            GetApplicationEventTarget(), 0, &reference)
        isRegistered = status == noErr
    }

    /// ⌘⌃Space, the theme switcher's shortcut.
    static func themeSwitcher(_ action: @escaping @MainActor () -> Void) -> HotKey {
        HotKey(keyCode: kVK_Space, modifiers: cmdKey | controlKey, action: action)
    }
}
