import Foundation

extension Doctor {
    /// A bar set up before the menu bar showed widgets, which setup moves
    /// onto them.
    static func layoutChecks() -> [HealthCheck] {
        guard Setup.barNeedsMoving else { return [] }
        return [
            HealthCheck(
                .configuration, "Menu bar", .warning,
                "Set up before the bar showed widgets; setup moves it onto them",
                fix: "Open Macarchy to set it up again", command: setupCommand)
        ]
    }
}
