import Foundation

/// Every widget that can go on the bar: the ones shipped in the app and the
/// ones in `~/Library/Application Support/Macarchy/widgets`.
///
/// Ids are unique across both. A person's folder that reuses a built-in id is
/// refused rather than shadowing it, so a built-in always means the same thing
/// and "Duplicate as my own" makes a new id instead.
public struct WidgetCatalogue: Sendable {
    public enum Origin: String, Codable, Sendable { case builtIn, user }

    public struct Entry: Sendable {
        public let id: String
        public let directory: URL
        public let manifest: WidgetManifest
        public let origin: Origin
    }

    public struct Snapshot: Sendable {
        public let entries: [Entry]
        /// Folders that could not be used, by folder name, with why.
        public let problems: [String: [WidgetProblem]]

        public func entry(_ id: String) -> Entry? { entries.first { $0.id == id } }
    }

    public let builtIn: URL?
    public let user: URL

    public init(
        builtIn: URL? = Paths.resources?.appending(path: "widgets"),
        user: URL = Paths.widgetsDirectory
    ) {
        self.builtIn = builtIn
        self.user = user
    }

    /// Reads both folders. A missing folder is normal: nobody has made a
    /// widget yet, or a development build has no resources.
    public func read() -> Snapshot {
        var entries: [Entry] = []
        var problems: [String: [WidgetProblem]] = [:]
        let roots: [(URL, Origin)] = [builtIn.map { ($0, .builtIn) }, (user, .user)].compactMap {
            $0
        }
        for (root, origin) in roots {
            for folder in Self.folders(in: root) {
                let name = folder.lastPathComponent
                guard Self.stays(folder, inside: root) else {
                    problems[name, default: []].append(
                        WidgetProblem(file: name, message: "links outside its widgets folder"))
                    continue
                }
                let check = WidgetManifest.check(folder: folder)
                guard let manifest = check.manifest, check.problems.isEmpty else {
                    problems[name, default: []] += check.problems
                    continue
                }
                if let existing = entries.first(where: { $0.id == manifest.id }) {
                    let message =
                        existing.origin == .builtIn
                        ? "\(manifest.id) is the id of a built-in widget; give this one another id and folder name"
                        : "\(manifest.id) is already used by another widget"
                    problems[name, default: []].append(WidgetProblem(message: message))
                    continue
                }
                entries.append(
                    Entry(id: manifest.id, directory: folder, manifest: manifest, origin: origin))
            }
        }
        return Snapshot(entries: entries, problems: problems)
    }

    /// Ids a new widget cannot have: every widget's, and every folder name in
    /// the person's widgets folder, including ones too broken to load.
    public func takenIDs() -> Set<String> {
        Set(read().entries.map(\.id)).union(Self.folders(in: user).map(\.lastPathComponent))
    }

    /// An id that is not in `taken`, from `base` and then `base-2`, `base-3`.
    public static func unusedID(from base: String, taken: Set<String>) -> String {
        if !taken.contains(base) { return base }
        var number = 2
        while taken.contains("\(base)-\(number)") { number += 1 }
        return "\(base)-\(number)"
    }

    private static func folders(in root: URL) -> [URL] {
        let fm = FileManager.default
        guard
            let contents = try? fm.contentsOfDirectory(
                at: root, includingPropertiesForKeys: [.isDirectoryKey])
        else { return [] }
        return contents.filter { url in
            !url.lastPathComponent.hasPrefix(".")
                && (try? url.resolvingSymlinksInPath().resourceValues(forKeys: [.isDirectoryKey])
                    .isDirectory) == true
        }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private static func stays(_ folder: URL, inside root: URL) -> Bool {
        folder.resolvingSymlinksInPath().path.hasPrefix(root.resolvingSymlinksInPath().path + "/")
    }
}
