import Foundation
import CryptoKit

/// A config file the app authors.
///
/// Generated files are not made read-only. Locking them fights your editor,
/// breaks quick recovery, and does not actually prevent a write — it just makes
/// the failure confusing. Instead the app records a hash of what it last wrote,
/// and re-checks before overwriting: a file that no longer matches was edited
/// by hand, so it gets snapshotted and reported rather than silently discarded.
public struct GeneratedFile: Sendable {
    public let url: URL

    /// Where the "what did we last generate" hashes are recorded.
    ///
    /// Injectable because it is shared mutable state on disk: leaving it as a
    /// hard-coded global made concurrent writers clobber each other's entries
    /// and let tests pollute the real ledger with temporary paths.
    public let ledgerURL: URL

    public init(url: URL, ledgerURL: URL = Paths.appRoot.appending(path: "generated.json")) {
        self.url = url
        self.ledgerURL = ledgerURL
    }

    public static let beginKeep = "# >>> macarchy:keep"
    public static let endKeep = "# <<< macarchy:keep"

    public enum Outcome: Sendable, Equatable {
        case unchanged
        case written
        /// The file on disk differed from what we last generated.
        case writtenOverDrift(snapshot: String?)
        case failed(String)

        public var isDrift: Bool { if case .writtenOverDrift = self { true } else { false } }
    }

    // MARK: - Ledger

    /// A missing ledger is empty; an unreadable one is an error, because
    /// treating it as empty would silently switch off drift detection.
    private func ledger() throws -> [String: String] {
        guard FileManager.default.fileExists(atPath: ledgerURL.path) else { return [:] }
        do {
            return try JSONDecoder().decode(
                [String: String].self, from: Data(contentsOf: ledgerURL))
        } catch {
            throw ConfigurationError(
                "\(ledgerURL.lastPathComponent) is unreadable: \(error.localizedDescription)")
        }
    }

    private func recordHash(_ hash: String, for path: String) throws {
        try FileLock.withLock(ledgerURL) {
            var current = try ledger()
            current[path] = hash
            let data = try JSONEncoder().encode(current)
            try data.write(to: ledgerURL, options: .atomic)
        }
    }

    public static func hash(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// The hash recorded for a generated file. Keep regions are blanked first,
    /// because edits inside them are the person's to make and are not drift.
    public static func generatedHash(_ text: String) -> String {
        var lines: [Substring] = []
        var inside = false
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(beginKeep) { inside = true; lines.append(line); continue }
            if trimmed.hasPrefix(endKeep) { inside = false }
            if !inside { lines.append(line) }
        }
        return hash(lines.joined(separator: "\n"))
    }

    /// True when the file on disk differs from what the app last generated
    /// outside its keep regions. Ledgers written before regions were ignored
    /// hold a whole-file hash, which still counts as a match.
    public var hasDrifted: Bool {
        guard let recorded = (try? ledger())?[url.path],
            let onDisk = try? String(contentsOf: url, encoding: .utf8)
        else { return false }
        return Self.generatedHash(onDisk) != recorded && Self.hash(onDisk) != recorded
    }

    // MARK: - Preserved regions

    /// Pulls out `# >>> macarchy:keep <name>` … `# <<< macarchy:keep` blocks so
    /// hand-written parts of a file survive regeneration.
    public static func preservedRegions(in text: String) -> [String: String] {
        var regions: [String: String] = [:]
        var name: String?
        var buffer: [String] = []

        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(beginKeep) {
                name = trimmed.dropFirst(beginKeep.count).trimmingCharacters(in: .whitespaces)
                buffer = []
            } else if trimmed.hasPrefix(endKeep), let open = name {
                regions[open] = buffer.joined(separator: "\n")
                name = nil
            } else if name != nil {
                buffer.append(String(line))
            }
        }
        return regions
    }

    public func preservedRegions() -> [String: String] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
        return Self.preservedRegions(in: text)
    }

    // MARK: - Writing

    @discardableResult
    public func write(_ content: String, reason: String) -> Outcome {
        let fm = FileManager.default
        let existing = try? String(contentsOf: url, encoding: .utf8)

        if existing == content {
            // Keeps the ledger current when only its hashing has changed.
            if (try? ledger())?[url.path] != Self.generatedHash(content) {
                try? recordHash(Self.generatedHash(content), for: url.path)
            }
            return .unchanged
        }

        var driftSnapshot: String?
        do {
            if existing != nil {
                let snapshot = try SnapshotStore(
                    root: ledgerURL.deletingLastPathComponent().appending(path: "snapshots")
                ).capture([url], reason: reason)
                if hasDrifted { driftSnapshot = snapshot?.id }
            }
            try fm.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try content.write(to: url, atomically: true, encoding: .utf8)

            // Generated rc files are executed by launchd, so they must stay executable.
            if content.hasPrefix("#!") {
                try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
            }
            try recordHash(Self.generatedHash(content), for: url.path)
        } catch {
            return .failed(error.localizedDescription)
        }

        return driftSnapshot != nil ? .writtenOverDrift(snapshot: driftSnapshot) : .written
    }
}
