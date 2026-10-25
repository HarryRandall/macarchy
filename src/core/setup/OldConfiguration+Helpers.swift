import Darwin
import Foundation

/// Programs an old bar left running from a folder cleaning up deletes.
///
/// A bar's helpers often keep a pid file and a named pipe in a state folder
/// beside their scripts. Once the folder goes, such a helper keeps running
/// with nothing to read it, so cleaning up stops one when it can tell it
/// is that helper: a pid file in the folder names it, and the process runs
/// a script from inside that folder. Any other pid is left alone and reported.
extension OldConfiguration {
    /// Stops the helpers found in `folders`, returning what it did.
    static func stopHelpers(in folders: [URL]) -> [String] {
        var lines: [String] = []
        for folder in folders {
            for pidFile in pidFiles(under: folder) {
                guard let pid = pid(in: pidFile), let arguments = arguments(of: pid) else {
                    continue
                }
                guard let script = script(in: arguments),
                    DesktopIsolation.inside(script, roots: [folder.path])
                else {
                    lines.append(
                        "Left process \(pid) running: \(Paths.display(pidFile)) names it, but it "
                            + "does not run a script from \(Paths.display(folder))")
                    continue
                }
                let label = Paths.display(URL(fileURLWithPath: script))
                if let refusal = DesktopIsolation.signalRefusal(script) {
                    lines.append("Left \(label) (process \(pid)) running: \(refusal)")
                } else if kill(pid, SIGTERM) == 0 {
                    lines.append(
                        "Stopped \(label) (process \(pid)), which was still running from a folder "
                            + "cleaning up deletes")
                } else {
                    lines.append(
                        "Could not stop \(label) (process \(pid)): "
                            + String(cString: strerror(errno)))
                }
            }
        }
        return lines
    }

    /// Small regular files named `*.pid`, links not followed.
    static func pidFiles(under folder: URL) -> [URL] {
        guard let walk = FileManager.default.enumerator(atPath: folder.path) else { return [] }
        var found: [URL] = []
        while let relative = walk.nextObject() as? String {
            let url = folder.appending(path: relative)
            if url.pathExtension == "pid", fingerprint(url) == .file { found.append(url) }
        }
        return found.sorted { $0.path < $1.path }
    }

    static func pid(in file: URL) -> pid_t? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
            (attributes[.size] as? Int ?? .max) <= 32,
            let text = try? String(contentsOf: file, encoding: .utf8),
            let pid = pid_t(text.trimmingCharacters(in: .whitespacesAndNewlines)),
            pid > 1, pid != getpid()
        else { return nil }
        return pid
    }

    /// The script a command line runs: the executable itself, or the first
    /// argument after it that is not an option, as `bash script.sh` has it.
    static func script(in arguments: [String]) -> String? {
        guard let executable = arguments.first else { return nil }
        if executable.hasPrefix("/"), !isInterpreter(executable) { return executable }
        return arguments.dropFirst().first { !$0.hasPrefix("-") }
    }

    private static func isInterpreter(_ path: String) -> Bool {
        let name = URL(fileURLWithPath: path).lastPathComponent
        return ["sh", "bash", "zsh", "dash", "ksh", "env", "lua", "perl", "ruby"].contains(name)
            || name.hasPrefix("python")
    }

    /// A running process's arguments, or nil when it is not running or not
    /// this user's.
    static func arguments(of pid: pid_t) -> [String]? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else {
            return nil
        }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size
        else { return nil }
        let count = buffer.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) }
        var index = MemoryLayout<Int32>.size
        // The executable's path, then padding, then the arguments.
        while index < size, buffer[index] != 0 { index += 1 }
        while index < size, buffer[index] == 0 { index += 1 }
        var arguments: [String] = []
        while arguments.count < count, index < size {
            let start = index
            while index < size, buffer[index] != 0 { index += 1 }
            arguments.append(String(bytes: buffer[start..<index], encoding: .utf8) ?? "")
            index += 1
        }
        return arguments
    }
}
