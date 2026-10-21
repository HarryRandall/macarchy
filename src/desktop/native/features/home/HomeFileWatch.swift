import Foundation
import Macarchy

/// Shortcuts and theme packages can change without a settings.json write.
/// A small fingerprint also notices atomic replacements in nested folders.
@MainActor
final class HomeFileWatch {
    private var timer: Timer?
    private var previous: [String] = []

    func start(changed: @escaping @MainActor () -> Void) {
        previous = fingerprint()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let next = self.fingerprint()
                if next != self.previous {
                    self.previous = next
                    changed()
                }
            }
        }
    }

    /// The skhdrc entry is the file the core reads: possibly `~/.skhdrc`, or
    /// the target of a symlink into a dotfiles repository.
    func fingerprint() -> [String] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey]
        func entry(_ url: URL) -> String? {
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
            let modified = values.contentModificationDate?.timeIntervalSince1970 ?? 0
            return "\(url.path):\(modified):\(values.fileSize ?? 0)"
        }
        let skhdrc = SkhdShortcuts().configURL
        var result = [entry(skhdrc) ?? "\(skhdrc.path):missing"]
        for root in [Paths.themesDirectory, Paths.snapshotsDirectory] {
            guard let entries = fm.enumerator(at: root, includingPropertiesForKeys: keys) else {
                continue
            }
            for case let url as URL in entries {
                if let line = entry(url) { result.append(line) }
            }
        }
        return result.sorted()
    }
}
