import AppKit

/// Borderless panels refuse key status by default, which would stop typing.
final class SwitcherWindow: NSPanel {
    var onResign: (() -> Void)?
    /// Set while the panel fades out. Clicks and keys are dropped then, so a
    /// second Return cannot apply again from a panel already on its way out.
    var isDismissing = false
    override var canBecomeKey: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        if drops(event) { return }
        super.sendEvent(event)
    }

    func drops(_ event: NSEvent) -> Bool {
        isDismissing && Self.inputEvents.contains(event.type)
    }

    private static let inputEvents: Set<NSEvent.EventType> = [
        .keyDown, .keyUp, .flagsChanged, .leftMouseDown, .leftMouseUp, .rightMouseDown,
        .rightMouseUp, .otherMouseDown, .otherMouseUp, .scrollWheel
    ]

    override func resignKey() {
        super.resignKey()
        onResign?()
    }
}
