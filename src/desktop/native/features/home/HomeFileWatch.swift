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

    private func fingerprint() -> [String] {
        let fm = FileManager.default
        let roots = [
            Paths.themesDirectory, Paths.snapshotsDirectory,
            Paths.home.appending(path: ".config/skhd")
        ]
        var result: [String] = []
        for root in roots {
            guard
                let entries = fm.enumerator(
                    at: root,
                    includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey])
            else { continue }
            for case let url as URL in entries {
                guard
                    let values = try? url.resourceValues(
                        forKeys: [.contentModificationDateKey, .fileSizeKey])
                else { continue }
                result.append(
                    "\(url.path):\(values.contentModificationDate?.timeIntervalSince1970 ?? 0):\(values.fileSize ?? 0)"
                )
            }
        }
        return result.sorted()
    }
}
