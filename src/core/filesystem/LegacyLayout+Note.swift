import Foundation

extension LegacyLayout {
    /// What `move` did, kept in the new folder until setup reports it.
    ///
    /// The first command after an upgrade, usually a yabai signal, moves the
    /// folder before the person opens anything, so `move` writes this note
    /// and setup and the app tell them later. Setup clears it once its
    /// report has carried the lines.
    public struct Note: Codable, Sendable, Equatable {
        enum Kind: String, Codable, Sendable { case moved, merged, copied }

        var kind: Kind
        /// The old path, and the new folder.
        var from: String
        var to: String
        /// The folder a person's link led to, when it was copied.
        var copiedFrom: String?
        var setAside: String?

        static let fileName = "migration.json"

        init(_ outcome: Outcome, legacy: URL, root: URL) {
            from = legacy.path
            to = root.path
            switch outcome {
            case .nothing, .moved: kind = .moved
            case .merged(let aside):
                kind = .merged
                setAside = aside?.path
            case .copied(let source, let aside):
                kind = .copied
                copiedFrom = source.path
                setAside = aside?.path
            }
        }

        /// What happened, in the words setup reports.
        public var lines: [String] {
            let old = Paths.display(URL(fileURLWithPath: from))
            let new = Paths.display(URL(fileURLWithPath: to))
            var lines: [String]
            if let copiedFrom {
                let source = Paths.display(URL(fileURLWithPath: copiedFrom))
                lines = [
                    "Copied your settings from \(source), which \(old) links to, into \(new). "
                        + "Your link and that folder were left as they are; Macarchy no longer "
                        + "reads them"
                ]
            } else {
                lines = ["Moved \(old) to \(new)"]
            }
            if let setAside {
                lines.append(
                    "Files that were already in \(new) and clashed are in "
                        + Paths.display(URL(fileURLWithPath: setAside)))
            }
            return lines
        }

        func save(in root: URL) {
            guard let data = try? JSONEncoder().encode(self) else { return }
            try? data.write(to: root.appending(path: Self.fileName), options: .atomic)
        }

        static func load(from root: URL) -> Note? {
            guard let data = try? Data(contentsOf: root.appending(path: fileName)) else {
                return nil
            }
            return try? JSONDecoder().decode(Note.self, from: data)
        }
    }

    /// The note `move` left, until setup has reported it.
    public static var note: Note? { Note.load(from: Paths.appRoot) }

    /// Called once setup's report carries the note's lines.
    static func clearNote() {
        try? FileManager.default.removeItem(at: Paths.appRoot.appending(path: Note.fileName))
    }
}
