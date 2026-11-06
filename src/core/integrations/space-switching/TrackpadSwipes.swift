import Foundation
import SpaceGesture

/// Instant trackpad swipes: the trackpad's sideways swipe between Spaces
/// switches at once through a `SpaceSwitcher` instead of sliding.
///
/// Off unless turned on in settings. Only the app catches swipes, as it is
/// always running and sends the switches itself: on macOS 27 its own swipes
/// come back looking like the trackpad's, and only the process that posted
/// them can tell them apart. While the app is not running, swipes slide as
/// macOS normally does.
@MainActor
public enum TrackpadSwipes {
    public typealias Handler = @MainActor (SpaceSwitcher.Direction) -> Void
    private static var onSwipe: Handler?

    /// Whether settings ask for instant swipes.
    public static var wanted: Bool {
        (try? SettingsStore().read())?.trackpadSwipes ?? false
    }

    public static func setWanted(_ on: Bool) throws {
        try SettingsStore().update { $0.trackpadSwipes = on }
    }

    /// Starts catching swipes, calling `handler` with each one's direction.
    /// False without Accessibility, and always in an isolated run.
    @discardableResult
    public static func start(_ handler: @escaping Handler) -> Bool {
        guard !DesktopIsolation.isActive else { return false }
        onSwipe = handler
        let started = sg_swipe_override_start { direction in
            // The tap runs on the main run loop.
            MainActor.assumeIsolated {
                TrackpadSwipes.onSwipe?(direction == SGDirectionRight ? .right : .left)
            }
        }
        if !started { onSwipe = nil }
        return started
    }

    public static func stop() {
        sg_swipe_override_stop()
        onSwipe = nil
    }
}
