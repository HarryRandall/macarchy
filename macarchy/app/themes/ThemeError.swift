import Foundation

enum ThemeError: LocalizedError {
    case notAPackage
    case alreadyInstalled(String)
    case noDefault(String)

    var errorDescription: String? {
        switch self {
        case .notAPackage:
            "That folder has no theme.json, so it isn't a theme package."
        case .alreadyInstalled(let name):
            "A theme called \(name) is already installed. Remove it first, or rename the import."
        case .noDefault(let name):
            "\(name) didn't ship with the app, so there's no default to restore."
        }
    }
}
