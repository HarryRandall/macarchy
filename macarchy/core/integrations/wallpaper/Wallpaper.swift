import AppKit
import CoreGraphics
import Foundation

/// Sets the desktop picture on every Space, live.
///
/// The public API, `NSWorkspace.setDesktopImageURL`, only reaches the Space on
/// screen. Editing the wallpaper store does nothing to the running agent, and
/// restarting the agent blanks every desktop to grey while it comes back.
///
/// WallpaperServices has the per-Space entry point System Settings uses. It
/// talks to the running agent over XPC, so every Space updates in place. It is
/// private, so when it is missing this falls back to the current Space only.
public enum Wallpaper {
    public enum Outcome: Sendable, Equatable {
        case allSpaces(Int)
        case currentSpaceOnly
    }

    @MainActor
    public static func set(_ image: URL) throws -> Outcome {
        guard FileManager.default.fileExists(atPath: image.path) else {
            throw ConfigurationError("Wallpaper not found: \(Paths.display(image))")
        }
        if let client = makeClient() {
            let spaces = allSpaceUUIDs()
            let displays = activeDisplays()
            var applied = 0
            for uuid in spaces {
                // A Space lives on one display; the calls for the others are no-ops.
                let succeeded = displays.contains { display in
                    var error: NSError?
                    return client.setImageURL(
                        image as NSURL, forSpace: uuid as NSString, displayID: display,
                        options: 0, error: &error)
                }
                if succeeded { applied += 1 }
            }
            if !spaces.isEmpty, applied == spaces.count { return .allSpaces(applied) }
        }
        for screen in NSScreen.screens {
            try NSWorkspace.shared.setDesktopImageURL(image, for: screen, options: [:])
        }
        return .currentSpaceOnly
    }

    private static func makeClient() -> WallpaperServicesClient? {
        guard
            dlopen(
                "/System/Library/PrivateFrameworks/WallpaperServices.framework/WallpaperServices",
                RTLD_NOW) != nil,
            let type = NSClassFromString("WPSWallpaperServicesClient") as? NSObject.Type
        else { return nil }
        let client = type.init()
        let selector = NSSelectorFromString("setImageURL:forSpace:displayID:options:error:")
        guard client.responds(to: selector) else { return nil }
        return unsafeBitCast(client, to: WallpaperServicesClient.self)
    }

    private static func activeDisplays() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        guard count > 0 else { return [CGMainDisplayID()] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &ids, &count)
        return Array(ids.prefix(Int(count)))
    }

    /// Every Space the window server knows about, without needing yabai.
    private static func allSpaceUUIDs() -> [String] {
        guard
            let skylight = dlopen(
                "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW),
            let connection = dlsym(skylight, "CGSMainConnectionID"),
            let copy = dlsym(skylight, "CGSCopyManagedDisplaySpaces")
        else { return [] }
        typealias MainConnectionID = @convention(c) () -> Int32
        typealias CopyManagedDisplaySpaces = @convention(c) (Int32) -> Unmanaged<CFArray>?
        let id = unsafeBitCast(connection, to: MainConnectionID.self)()
        guard let managed = unsafeBitCast(copy, to: CopyManagedDisplaySpaces.self)(id) else {
            return []
        }
        let displays = managed.takeRetainedValue() as? [[String: Any]] ?? []
        var uuids: [String] = []
        for display in displays {
            for space in display["Spaces"] as? [[String: Any]] ?? [] {
                if let uuid = space["uuid"] as? String, !uuids.contains(uuid) { uuids.append(uuid) }
            }
        }
        return uuids
    }
}

@objc private protocol WallpaperServicesClient {
    @objc(setImageURL:forSpace:displayID:options:error:)
    func setImageURL(
        _ url: NSURL, forSpace space: NSString, displayID: UInt32,
        options: UInt64, error: UnsafeMutablePointer<NSError?>?
    ) -> Bool
}
