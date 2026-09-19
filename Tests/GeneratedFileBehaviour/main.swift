import Foundation

// Generated files are not locked, so the guarantee is: a hand edit is noticed,
// preserved, and reported — never silently discarded. That is worth testing,
// because the failure mode is losing someone's config without telling them.

let sandbox = URL(fileURLWithPath: NSHomeDirectory()).appending(path: ".cache/genfiletest")
try? FileManager.default.removeItem(at: sandbox)
try! FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)

let target = sandbox.appending(path: "testrc")
let file = GeneratedFile(url: target)

let v1 = "#!/bin/bash\necho one\n"
print("first write:", file.write(v1, reason: "t") == .written ? "written" : "?", "(expected written)")
print("rewrite same content:", file.write(v1, reason: "t") == .unchanged ? "unchanged" : "?", "(expected unchanged)")

// Executable bit matters: launchd runs these.
let perms = (try? FileManager.default.attributesOfItem(atPath: target.path)[.posixPermissions] as? Int) ?? 0
print("executable bit:", perms == 0o755 ? "755" : String(perms, radix: 8), "(expected 755)")

print("no drift when untouched:", file.hasDrifted ? "yes" : "no", "(expected no)")

// Simulate a hand edit.
try! "#!/bin/bash\necho EDITED BY HAND\n".write(to: target, atomically: true, encoding: .utf8)
print("drift after hand edit:", file.hasDrifted ? "yes" : "no", "(expected yes)")

let outcome = file.write("#!/bin/bash\necho two\n", reason: "t")
print("hand edit reported:", outcome.isDrift ? "yes" : "no", "(expected yes)")
print("drift cleared after regenerate:", file.hasDrifted ? "yes" : "no", "(expected no)")

// Preserved regions survive regeneration.
let withKeep = """
#!/bin/bash
echo generated
\(GeneratedFile.beginKeep) extra
export MY_OWN_THING=1
\(GeneratedFile.endKeep)
"""
_ = file.write(withKeep, reason: "t")
let kept = file.preservedRegions()
print("keep block recovered:", kept["extra"]?.contains("MY_OWN_THING") == true ? "yes" : "no", "(expected yes)")

try? FileManager.default.removeItem(at: sandbox)
