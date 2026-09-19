import Foundation


// Parses the real skhdrc and reports what it found, so the numbers can be
// checked against the file by hand rather than trusted.
let path = NSHomeDirectory() + "/.config/skhd/skhdrc"
guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
    fputs("no skhdrc\n", stderr); exit(1)
}

let bindings = SkhdConfig.parse(text)
print("bindings parsed:", bindings.count)

let sections = Set(bindings.compactMap(\.section))
print("sections:", sections.count)

let noKey = bindings.filter { $0.key.isEmpty }
print("bindings with no key:", noKey.count, "(expected 0)")

let noCommand = bindings.filter { $0.command.isEmpty && $0.appOverrides.isEmpty }
print("bindings with no command:", noCommand.count, "(expected 0)")

let appSpecific = bindings.filter { !$0.appOverrides.isEmpty }
print("app-specific blocks:", appSpecific.count)
for binding in appSpecific {
    print("   \(binding.keyCaps.joined(separator: " ")) → \(binding.appOverrides.count) apps")
}

let mediaKeys = bindings.filter { $0.modifiers.isEmpty }
print("modifier-less (media) keys:", mediaKeys.map(\.key).joined(separator: ", "))

// Any command still containing a raw key spec means a split went wrong.
let suspicious = bindings.filter { $0.command.hasPrefix("-") || $0.command.hasPrefix(":") }
print("suspicious commands:", suspicious.count, "(expected 0)")

print()
print("sample:")
for binding in bindings.prefix(4) {
    print("  \(binding.keyCaps.joined(separator: " "))  →  \(binding.command.prefix(52))")
}
