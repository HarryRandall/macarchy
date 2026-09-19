import Foundation
import Observation
import Kit

/// Backs the console strip along the bottom of the window.
///
/// This app is a face over several command line tools, so hiding the shell-out
/// would be the wrong instinct — every command it runs is visible, and a failure
/// surfaces the daemon's own stderr rather than a paraphrase of it.
@MainActor
@Observable
final class CommandLog {
    struct Entry: Identifiable, Sendable {
        let id = UUID()
        let command: String
        let detail: String
        let ok: Bool
        let at: Date
    }

    private(set) var entries: [Entry] = []

    var latest: Entry? { entries.last }

    func record(_ result: CommandResult) {
        append(command: result.command, detail: result.summary, ok: result.ok)
    }

    func note(_ command: String, _ detail: String = "") {
        append(command: command, detail: detail, ok: true)
    }

    private func append(command: String, detail: String, ok: Bool) {
        entries.append(Entry(command: command, detail: detail, ok: ok, at: .now))
        if entries.count > 200 { entries.removeFirst(entries.count - 200) }
    }
}
