import Foundation

/// A problem before it has been given a line: where it is, and what it is.
struct WidgetFinding: Equatable {
    let path: [String]
    let message: String

    init(_ path: [String], _ message: String) {
        self.path = path
        self.message = message
    }
}

extension WidgetManifest {
    func findings(folder: URL?) -> [WidgetFinding] {
        var found: [WidgetFinding] = []
        func add(_ path: [String], _ message: String) { found.append(WidgetFinding(path, message)) }

        found += identityFindings(folder: folder)
        if source != nil, provider != nil {
            add(["provider"], "a widget has a source or a provider, not both")
        }
        if let source, !Self.sources.contains(source) {
            add(
                ["source"],
                "source \"\(source)\" is not a reading Macarchy provides; use one of \(Self.sources.joined(separator: ", "))"
            )
        }
        if let provider { found += providerFindings(provider, folder: folder) }
        if let label, let message = templateProblem(label) { add(["label"], "label \(message)") }
        for (key, setting) in settings ?? [:] {
            found += setting.findings(key: key)
        }
        if let style { found += style.findings() }
        if let update { found += update.findings() }
        if let click { found += click.findings(settings: settings ?? [:]) }
        for (index, permission) in (permissions ?? []).enumerated()
        where !Self.permissions.contains(permission) {
            add(["permissions", String(index)], "permissions can only list network for now")
        }
        return found
    }

    /// The schema, id, name and version.
    private func identityFindings(folder: URL?) -> [WidgetFinding] {
        var found: [WidgetFinding] = []
        func add(_ field: String, _ message: String) {
            found.append(WidgetFinding([field], message))
        }
        if schema != Self.schemaVersion {
            add("schema", "schema should be 1, the only version this Macarchy reads")
        }
        if !id.matches("^[a-z0-9][a-z0-9-]{0,39}$") {
            add("id", "id should be lower-case letters, numbers and hyphens, up to 40 characters")
        } else if let folder, folder.lastPathComponent != id {
            add(
                "id",
                "id is \"\(id)\" but the folder is called \"\(folder.lastPathComponent)\"; they should match"
            )
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { add("name", "name is empty") }
        if trimmed.count > 40 { add("name", "name should be 40 characters or fewer") }
        if !version.matches("^[0-9]+\\.[0-9]+\\.[0-9]+$") {
            add("version", "version should look like 1.0.0")
        }
        return found
    }

    private func providerFindings(_ provider: String, folder: URL?) -> [WidgetFinding] {
        guard !provider.isEmpty, !provider.contains("/"), !provider.hasPrefix(".") else {
            return [
                WidgetFinding(
                    ["provider"],
                    "provider should be a file in the widget's folder, such as provider.sh")
            ]
        }
        guard let folder else { return [] }
        let path = folder.appending(path: provider).path
        let fm = FileManager.default
        if !fm.fileExists(atPath: path) {
            return [WidgetFinding(["provider"], "\(provider) is not in the widget's folder")]
        }
        if !fm.isExecutableFile(atPath: path) {
            return [
                WidgetFinding(
                    ["provider"], "\(provider) is not executable; run chmod +x \(provider)")
            ]
        }
        return []
    }
}

/// Why a template cannot be used, or nil when its braces pair up.
func templateProblem(_ template: String) -> String? {
    var open = false
    for character in template {
        if character == "{" {
            if open { return "has a { inside another" }
            open = true
        } else if character == "}" {
            if !open { return "has a } with no { before it" }
            open = false
        }
    }
    return open ? "has a { that is never closed" : nil
}

extension WidgetSetting {
    func findings(key: String) -> [WidgetFinding] {
        var found: [WidgetFinding] = []
        let path = ["settings", key]
        func add(_ field: String?, _ message: String) {
            found.append(WidgetFinding(field.map { path + [$0] } ?? path, message))
        }
        if !key.matches("^[a-z][a-zA-Z0-9]{0,39}$") {
            add(
                nil, "setting names start with a lower-case letter and use only letters and numbers"
            )
        }
        guard Self.types.contains(type) else {
            add("type", "\(key).type should be one of \(Self.types.joined(separator: ", "))")
            return found
        }
        if label.trimmingCharacters(in: .whitespaces).isEmpty {
            add("label", "\(key).label is empty")
        }
        if options != nil, type != "choice" {
            add("options", "options only applies to choice settings")
        }
        if min != nil || max != nil || step != nil, type != "number" {
            add(nil, "min, max and step only apply to number settings")
        }
        return found + valueFindings(key: key, path: path)
    }

    /// Problems with the options, bounds and default, which depend on the type.
    private func valueFindings(key: String, path: [String]) -> [WidgetFinding] {
        var found: [WidgetFinding] = []
        let choices = options ?? []
        if type == "choice", choices.isEmpty {
            found.append(WidgetFinding(path + ["options"], "\(key) is a choice with no options"))
        }
        if Set(choices).count != choices.count {
            found.append(WidgetFinding(path + ["options"], "\(key) lists the same option twice"))
        }
        if let min, let max, min > max {
            found.append(WidgetFinding(path + ["min"], "\(key).min is more than its max"))
        }
        if let value = self.default, let message = mismatch(value) {
            found.append(WidgetFinding(path + ["default"], "\(key).default \(message)"))
        }
        return found
    }

    /// Why a value does not fit this setting, or nil when it does.
    func mismatch(_ value: SettingValue) -> String? {
        switch (type, value) {
        case ("toggle", .bool): return nil
        case ("toggle", _): return "should be true or false"
        case ("number", .number(let number)): return outOfRange(number)
        case ("number", _): return "should be a number"
        case ("choice", .text(let text)):
            return (options ?? []).contains(text)
                ? nil : "should be one of \((options ?? []).joined(separator: ", "))"
        case ("choice", _): return "should be one of its options, in quotes"
        case ("colour", .text(let text)):
            return WidgetStyle.themeColours.contains(text)
                || text.matches("^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$")
                ? nil : "should be text, accent, muted or a colour such as #a5b4fc"
        case ("format", .text(let text)): return templateProblem(text)
        case ("text", .text): return nil
        default: return "should be text in quotes"
        }
    }

    private func outOfRange(_ number: Double) -> String? {
        if !number.isFinite { return "should be a finite number" }
        if let min, number < min { return "should be at least \(SettingValue.number(min).string)" }
        if let max, number > max { return "should be at most \(SettingValue.number(max).string)" }
        return nil
    }
}

extension WidgetStyle {
    func findings() -> [WidgetFinding] {
        var found: [WidgetFinding] = []
        func add(_ field: String, _ message: String) {
            found.append(WidgetFinding(["style", field], message))
        }
        if let box, !Self.boxes.contains(box) {
            add("box", "style.box should be none, outline or fill")
        }
        func range(_ value: Double?, _ field: String, _ bounds: ClosedRange<Double>) {
            if let value, !(value.isFinite && bounds.contains(value)) {
                add(
                    field,
                    "style.\(field) should be from \(Int(bounds.lowerBound)) to \(Int(bounds.upperBound))"
                )
            }
        }
        range(size, "size", 8...24)
        range(radius, "radius", 0...20)
        range(paddingLeft, "paddingLeft", 0...40)
        range(paddingRight, "paddingRight", 0...40)
        if let lines, !(1...2).contains(lines) { add("lines", "style.lines should be 1 or 2") }
        if let row, !(1...Self.rowLimit).contains(row) {
            add("row", "style.row should be from 1 to \(Self.rowLimit)")
        }
        if row != nil && lines == 2 { add("row", "style.row and style.lines cannot both be set") }
        for (field, colour) in [("iconColour", iconColour), ("textColour", textColour)] {
            if let colour, !Self.themeColours.contains(colour),
                !colour.matches("^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$")
            {
                add(
                    field,
                    "style.\(field) should be text, accent, muted or a colour such as #a5b4fc")
            }
        }
        return found
    }
}

extension WidgetUpdate {
    func findings() -> [WidgetFinding] {
        var found: [WidgetFinding] = []
        if let every {
            if every == "stream" {
                found.append(
                    WidgetFinding(
                        ["update", "every"],
                        "update.every cannot be stream yet; use an interval such as 2s"))
            } else if !(every == "second" || every == "minute"
                || every.matches("^[1-9][0-9]{0,4}[smh]$"))
            {
                found.append(
                    WidgetFinding(
                        ["update", "every"],
                        "update.every should look like 1s, 5m or minute, not \"\(every)\""))
            } else if let seconds, seconds > 86_400 {
                found.append(
                    WidgetFinding(["update", "every"], "update.every should be a day or less"))
            }
        }
        for (index, event) in (events ?? []).enumerated()
        where !WidgetManifest.events.contains(event) {
            found.append(
                WidgetFinding(
                    ["update", "events", String(index)],
                    "\"\(event)\" is not an event; use one of \(WidgetManifest.events.joined(separator: ", "))"
                ))
        }
        return found
    }
}

extension WidgetClick {
    func findings(settings: [String: WidgetSetting]) -> [WidgetFinding] {
        var found: [WidgetFinding] = []
        let set = [open != nil, run != nil, dropdown != nil].filter { $0 }.count
        if set > 1 {
            found.append(WidgetFinding(["click"], "click should have one of open, run or dropdown"))
        }
        if let open, open.trimmingCharacters(in: .whitespaces).isEmpty {
            found.append(WidgetFinding(["click", "open"], "click.open is empty"))
        }
        if let run, run.trimmingCharacters(in: .whitespaces).isEmpty {
            found.append(WidgetFinding(["click", "run"], "click.run is empty"))
        }
        if let dropdown {
            if dropdown.isEmpty {
                found.append(WidgetFinding(["click", "dropdown"], "the dropdown has no rows"))
            }
            for (index, row) in dropdown.enumerated() {
                found += row.findings(index: index, settings: settings)
            }
        }
        return found
    }
}

extension String {
    func matches(_ pattern: String) -> Bool {
        range(of: pattern, options: .regularExpression) != nil
    }
}
