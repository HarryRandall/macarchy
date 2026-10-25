import Darwin
import Foundation
import Testing

@testable import App
@testable import Macarchy

/// An old bar with a state folder whose helper blocks reading its named
/// pipe, as a bar helper waits for readings, and a pid file naming it.
@MainActor
private func oldBar(_ harness: Harness, fifo: URL) throws -> Process {
    try harness.write("export A=1\n", to: ".config/sketchybar/colors.sh")
    try harness.write("{}\n", to: ".config/sketchybar/.state/readings.json")
    try harness.write(
        "#!/bin/bash\nread -r _ <> \"$1\"\n", to: ".config/sketchybar/plugins/stream.sh")
    #expect(mkfifo(fifo.path, 0o600) == 0)
    let helper = Process()
    helper.executableURL = URL(fileURLWithPath: "/bin/bash")
    helper.arguments = [
        harness.home.appending(path: ".config/sketchybar/plugins/stream.sh").path, fifo.path
    ]
    try helper.run()
    try harness.write("\(helper.processIdentifier)\n", to: ".config/sketchybar/.state/stream.pid")
    // A pid file naming a process that runs nothing from the folder.
    try harness.write("\(getppid())\n", to: ".config/sketchybar/.state/other.pid")
    return helper
}

/// An extended attribute's value, or nil without one.
private func attribute(_ name: String, of url: URL) -> String? {
    let size = getxattr(url.path, name, nil, 0, 0, XATTR_NOFOLLOW)
    guard size > 0 else { return nil }
    var buffer = [UInt8](repeating: 0, count: size)
    guard getxattr(url.path, name, &buffer, size, 0, XATTR_NOFOLLOW) == size else { return nil }
    return String(bytes: buffer, encoding: .utf8)
}

private func setAttribute(_ name: String, _ value: String, on url: URL) -> Bool {
    let bytes = Array(value.utf8)
    return setxattr(url.path, name, bytes, bytes.count, 0, XATTR_NOFOLLOW) == 0
}

extension WebInterfaceTests {
    /// Uses the parent's isolated environment without creating a web view.
    @MainActor
    @Suite("Archiving special files, attributes and what appears later")
    struct OldConfigurationSpecialFileTests {
        @Test("a named pipe is skipped, its helper stopped and its folder still deleted")
        func namedPipe() async throws {
            try await withHarness { harness in
                try upgradedHome(harness)
                let fm = FileManager.default
                let bar = harness.home.appending(path: ".config/sketchybar")
                let state = bar.appending(path: ".state")
                let fifo = state.appending(path: "stream.fifo")
                let helper = try oldBar(harness, fifo: fifo)
                defer { if helper.isRunning { helper.terminate() } }

                let plan = await OldConfiguration.plan()
                #expect(plan.removals.contains { $0.path.path == bar.path })
                let report = await OldConfiguration.apply(integrations: harness.model.backend)
                #expect(report.failure == nil, "\(report.lines)")
                #expect(!fm.fileExists(atPath: bar.path), "\(report.lines)")
                #expect(
                    report.lines.contains(
                        "Did not archive ~/.config/sketchybar/.state/stream.fifo, a named pipe "
                            + "only a running program uses; it is deleted with its folder"))
                let stopped = report.lines.contains {
                    $0.hasPrefix("Stopped ~/.config/sketchybar/plugins/stream.sh (process ")
                }
                #expect(stopped, "\(report.lines)")
                #expect(
                    report.lines.contains(
                        "Left process \(getppid()) running: ~/.config/sketchybar/.state/other.pid "
                            + "names it, but it does not run a script from ~/.config/sketchybar"))
                if stopped {
                    helper.waitUntilExit()
                    #expect(helper.terminationReason == .uncaughtSignal)
                }

                let archive = try #require(report.archive)
                let work = fm.temporaryDirectory.appending(path: "macarchy-test-\(UUID())")
                try fm.createDirectory(at: work, withIntermediateDirectories: true)
                defer { try? fm.removeItem(at: work) }
                let (manifest, files) = try await OldConfiguration.unpack(archive, into: work)
                #expect(
                    manifest.entries.contains {
                        $0.path == ".config/sketchybar/.state/stream.fifo" && $0.action == .skipped
                    })
                #expect(
                    fm.fileExists(
                        atPath: files.appending(path: ".config/sketchybar/colors.sh").path))

                let restored = await OldConfiguration.restore(
                    archive.lastPathComponent, integrations: harness.model.backend)
                #expect(restored.failure == nil, "\(restored.lines)")
                #expect(fm.fileExists(atPath: state.appending(path: "readings.json").path))
                #expect(!OldConfiguration.exists(fifo))
                #expect(
                    restored.lines.contains {
                        $0.hasPrefix("Not in the archive: ~/.config/sketchybar/.state/stream.fifo")
                    })
            }
        }

        @Test("a failure before anything changes says nothing was changed")
        func failsBeforeChanging() async throws {
            try await withHarness { harness in
                try upgradedHome(harness)
                // A file it cannot read stops the archive.
                try FileManager.default.setAttributes(
                    [.posixPermissions: 0],
                    ofItemAtPath: harness.home.appending(path: ".config/yabai/launch.sh.backup-1")
                        .path)
                let before = cleanupTree(harness)
                let report = await OldConfiguration.apply(integrations: harness.model.backend)
                let failure = try #require(report.failure)
                #expect(failure.hasSuffix("Nothing was changed."), "\(failure)")
                #expect(!failure.contains("part way"))
                #expect(cleanupTree(harness) == before)
            }
        }

        @Test("deleting leaves what appeared after archiving and keeps its folder")
        func deletesOnlyWhatWasArchived() async throws {
            try await withHarness { harness in
                let fm = FileManager.default
                try harness.write("a\n", to: "old/kept/a.txt")
                try harness.write("b\n", to: "old/b.txt")
                try fm.createSymbolicLink(
                    atPath: harness.home.appending(path: "old/link").path,
                    withDestinationPath: "b.txt")
                #expect(mkfifo(harness.home.appending(path: "old/pipe").path, 0o600) == 0)
                let old = harness.home.appending(path: "old")
                let copy = harness.home.appending(path: "copy")
                var copied = OldConfiguration.Copied()
                try OldConfiguration.copyTree(old, to: copy, key: "old", into: &copied)
                #expect(copied.skipped == ["old/pipe"])
                #expect(!OldConfiguration.exists(copy.appending(path: "pipe")))
                #expect(
                    try fm.destinationOfSymbolicLink(atPath: copy.appending(path: "link").path)
                        == "b.txt")
                #expect(copied.prints["old/kept/a.txt"] == .file)

                try harness.write("late\n", to: "old/kept/late.txt")
                var left: [URL] = []
                let gone = try OldConfiguration.deleteArchived(
                    old, key: "old", archived: copied.prints, left: &left)
                #expect(!gone)
                #expect(left.map(\.lastPathComponent) == ["late.txt"])
                #expect(try fm.contentsOfDirectory(atPath: old.path) == ["kept"])
                #expect(
                    try fm.contentsOfDirectory(atPath: old.appending(path: "kept").path) == [
                        "late.txt"
                    ])
            }
        }

        @Test(
            "only a helper running from the folder may be stopped, and never from a test's real home"
        )
        func helperRules() {
            #expect(
                OldConfiguration.script(in: ["/bin/bash", "/h/.config/sketchybar/a.sh", "--run"])
                    == "/h/.config/sketchybar/a.sh")
            #expect(OldConfiguration.script(in: ["/h/bin/tool", "-x"]) == "/h/bin/tool")
            #expect(OldConfiguration.script(in: ["/usr/bin/env", "-i", "x.py"]) == "x.py")
            #expect(OldConfiguration.arguments(of: getpid())?.isEmpty == false)
            #expect(
                DesktopIsolation.signalRefusal(NSHomeDirectory() + "/.config/sketchybar/a.sh")
                    != nil)
        }

        @Test("extended attributes survive the move, the archive and restoring")
        func keepsAttributes() async throws {
            try await withHarness { harness in
                try upgradedHome(harness)
                let yabai = harness.home.appending(path: ".config/yabai")
                let name = "io.github.harryrandall.test"
                #expect(setAttribute(name, "moved", on: yabai.appending(path: "mine.sh")))
                #expect(
                    setAttribute(name, "deleted", on: yabai.appending(path: "launch.sh.backup-1")))
                let report = await OldConfiguration.apply(integrations: harness.model.backend)
                #expect(report.failure == nil, "\(report.lines)")
                #expect(
                    attribute(name, of: Paths.scriptsDirectory.appending(path: "mine.sh"))
                        == "moved")
                let restored = await OldConfiguration.restore(
                    try #require(report.archive).lastPathComponent,
                    integrations: harness.model.backend)
                #expect(restored.failure == nil, "\(restored.lines)")
                #expect(attribute(name, of: yabai.appending(path: "mine.sh")) == "moved")
                #expect(
                    attribute(name, of: yabai.appending(path: "launch.sh.backup-1")) == "deleted")
            }
        }
    }
}
