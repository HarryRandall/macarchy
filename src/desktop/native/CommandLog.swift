import Foundation
import Observation
import Macarchy

/// Session activity, retaining both output streams for troubleshooting.
@MainActor
@Observable
final class CommandLog {
    struct Entry: Identifiable, Sendable {
        let id = UUID()
        let command: String
        let detail: String
        let ok: Bool
        let at: Date
        let status: Int32?
    }

    private(set) var entries: [Entry] = []

    var latest: Entry? { entries.last }

    func record(_ result: CommandResult) {
        let output = [
            result.stdout.isEmpty ? nil : "Standard output:\n\(result.stdout)",
            result.stderr.isEmpty ? nil : "Standard error:\n\(result.stderr)"
        ].compactMap { $0 }.joined(separator: "\n\n")
        append(command: result.command, detail: output, ok: result.ok, status: result.status)
    }

    func note(_ command: String, _ detail: String = "") {
        append(command: command, detail: detail, ok: true)
    }

    /// A failure that did not come from a command, such as an unreadable file.
    func failure(_ command: String, _ detail: String = "") {
        append(command: command, detail: detail, ok: false)
    }

    func clear() {
        entries.removeAll()
    }

    func remove(_ id: Entry.ID) {
        entries.removeAll { $0.id == id }
    }

    private func append(command: String, detail: String, ok: Bool, status: Int32? = nil) {
        entries.append(Entry(command: command, detail: detail, ok: ok, at: .now, status: status))
        if entries.count > 200 { entries.removeFirst(entries.count - 200) }
    }
}

extension CommandLog.Entry {
    /// Older activity notes have no source field, so classify their recorded
    /// command without changing the messages copied for troubleshooting.
    var category: ConsoleCategory {
        let text = command.lowercased()
        if text.contains("sketchybar") || text.contains("menu bar") { return .menuBar }
        if text.contains("borders") { return .borders }
        if text.contains("theme") { return .themes }
        if text.contains("skhd") || text.contains("shortcut") { return .shortcuts }
        if text.contains("rule") { return .rules }
        if text.contains("yabai") || text.contains("layout") { return .layout }
        if text.contains("restore") || text.contains("snapshot") { return .backups }
        return .system
    }

    var copyText: String {
        let outcome = status.map { "Exit \($0)" } ?? "Activity"
        return "[\(at.formatted(date: .numeric, time: .standard))] \(outcome)\n\(command)"
            + (detail.isEmpty ? "" : "\n\(detail)")
    }
}

enum ConsoleCategory: String, CaseIterable, Identifiable {
    case menuBar = "Menu Bar"
    case borders = "Borders"
    case themes = "Themes"
    case shortcuts = "Shortcuts"
    case rules = "Window Rules"
    case layout = "Layout"
    case backups = "Backups"
    case system = "System"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .menuBar: "menubar.rectangle"
        case .borders: "square.dashed"
        case .themes: "paintpalette"
        case .shortcuts: "command"
        case .rules: "flag"
        case .layout: "rectangle.3.group"
        case .backups: "clock.arrow.circlepath"
        case .system: "gearshape"
        }
    }
}
