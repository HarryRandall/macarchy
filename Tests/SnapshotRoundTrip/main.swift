import Foundation

let sandbox = URL(fileURLWithPath: NSHomeDirectory()).appending(path: ".cache/snaptest")
try? FileManager.default.removeItem(at: sandbox)
try! FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)

let target = sandbox.appending(path: "settings.env")
let store = SnapshotStore(root: sandbox.appending(path: "snapshots"), keep: 3)

func read() -> String { (try? String(contentsOf: target, encoding: .utf8)) ?? "<missing>" }

try! "VERSION=1\n".write(to: target, atomically: true, encoding: .utf8)
let first = try! store.capture([target], reason: "v1")
print("captured v1:", first?.id ?? "nil")

try! "VERSION=2\n".write(to: target, atomically: true, encoding: .utf8)
print("file now:", read().trimmingCharacters(in: .whitespacesAndNewlines))

// Restore should bring v1 back and snapshot v2 on the way.
try! store.restore(first!)
print("after restore:", read().trimmingCharacters(in: .whitespacesAndNewlines), "(expected VERSION=1)")
print("restore was itself snapshotted:", store.list().count >= 2)

// Pruning: keep=3, so ten captures must leave exactly three.
for i in 3...12 {
    try! "VERSION=\(i)\n".write(to: target, atomically: true, encoding: .utf8)
    _ = try! store.capture([target], reason: "v\(i)")
}
print("after 10 more captures, kept:", store.list().count, "(expected 3)")

// A file that doesn't exist must be skipped, not fatal.
let missing = sandbox.appending(path: "nope.env")
let none = try! store.capture([missing], reason: "missing only")
print("missing-only capture returns nil:", none == nil)

try? FileManager.default.removeItem(at: sandbox)
