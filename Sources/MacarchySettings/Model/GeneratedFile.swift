import Foundation
import CryptoKit

/// A config file the app authors.
///
/// Generated files are not made read-only. Locking them fights your editor,
/// breaks quick recovery, and does not actually prevent a write — it just makes
/// the failure confusing. Instead the app records a hash of what it last wrote,
/// and re-checks before overwriting: a file that no longer matches was edited
/// by hand, so it gets snapshotted and reported rather than silently discarded.
struct GeneratedFile: Sendable {
    let url: URL

    static let beginKeep = "# >>> macarchy:keep"
    static let endKeep = "# <<< macarchy:keep"

    enum Outcome: Sendable, Equatable {
        case unchanged
        case written
        /// The file on disk differed from what we last generated.
        case writtenOverDrift(snapshot: String?)
        case failed(String)

        var isDrift: Bool { if case .writtenOverDrift = self { true } else { false } }
    }

    // MARK: - Ledger

    private static var ledgerURL: URL { Paths.appRoot.appending(path: "generated.json") }

    private static func ledger() -> [String: String] {
        guard let data = try? Data(contentsOf: ledgerURL),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return decoded
    }

    private static func recordHash(_ hash: String, for path: String) {
        var current = ledger()
        current[path] = hash
        guard let data = try? JSONEncoder().encode(current) else { return }
        try? FileManager.default.createDirectory(at: Paths.appRoot, withIntermediateDirectories: true)
        try? data.write(to: ledgerURL, options: .atomic)
    }

    static func hash(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// True when the file on disk is not what the app last generated.
    var hasDrifted: Bool {
        guard let recorded = Self.ledger()[url.path],
              let onDisk = try? String(contentsOf: url, encoding: .utf8)
        else { return false }
        return Self.hash(onDisk) != recorded
    }

    // MARK: - Preserved regions

    /// Pulls out `# >>> macarchy:keep <name>` … `# <<< macarchy:keep` blocks so
    /// hand-written parts of a file survive regeneration.
    static func preservedRegions(in text: String) -> [String: String] {
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

    func preservedRegions() -> [String: String] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
        return Self.preservedRegions(in: text)
    }

    // MARK: - Writing

    @discardableResult
    func write(_ content: String, reason: String) -> Outcome {
        let fm = FileManager.default
        let existing = try? String(contentsOf: url, encoding: .utf8)

        if existing == content { return .unchanged }

        var driftSnapshot: String?
        if existing != nil && hasDrifted {
            driftSnapshot = try? SnapshotStore()
                .capture([url], reason: "hand-edited \(url.lastPathComponent) before regenerate")?.id
        }

        do {
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try content.write(to: url, atomically: true, encoding: .utf8)

            // Generated rc files are executed by launchd, so they must stay executable.
            if content.hasPrefix("#!") {
                try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
            }
            Self.recordHash(Self.hash(content), for: url.path)
        } catch {
            return .failed(error.localizedDescription)
        }

        return driftSnapshot != nil ? .writtenOverDrift(snapshot: driftSnapshot) : .written
    }
}
