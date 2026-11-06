import Foundation

/// Something wrong with a widget, written for the person who made it.
public struct WidgetProblem: Equatable, Sendable, CustomStringConvertible {
    public let file: String
    public let line: Int?
    public let message: String

    public init(file: String = WidgetManifest.fileName, line: Int? = nil, message: String) {
        self.file = file
        self.line = line
        self.message = message
    }

    public var description: String {
        line.map { "\(file), line \($0): \(message)" } ?? "\(file): \(message)"
    }
}

/// The result of reading a widget folder: the manifest when it decoded, and
/// every problem found, so one pass shows everything to fix.
public struct WidgetCheck: Sendable {
    public let manifest: WidgetManifest?
    public let problems: [WidgetProblem]
    public var ok: Bool { manifest != nil && problems.isEmpty }
}

extension WidgetManifest {
    /// Larger than any honest manifest; reading stops there.
    static let maximumSize = 256 * 1024

    /// Reads and checks the manifest in `folder`, including that its id
    /// matches the folder and that its provider is there and executable.
    public static func check(folder: URL) -> WidgetCheck {
        let url = folder.appending(path: fileName)
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size <= maximumSize else {
            return WidgetCheck(
                manifest: nil, problems: [WidgetProblem(message: "is larger than 256 KB")])
        }
        guard let data = try? Data(contentsOf: url) else {
            return WidgetCheck(
                manifest: nil,
                problems: [
                    WidgetProblem(message: "is missing from \(folder.lastPathComponent)")
                ])
        }
        return check(data: data, folder: folder)
    }

    /// Reads and checks manifest text. Without a folder, checks that need
    /// the files around it are skipped.
    public static func check(data: Data, folder: URL? = nil) -> WidgetCheck {
        guard data.count <= maximumSize else {
            return WidgetCheck(
                manifest: nil, problems: [WidgetProblem(message: "is larger than 256 KB")])
        }
        guard let text = String(data: data, encoding: .utf8) else {
            return WidgetCheck(
                manifest: nil, problems: [WidgetProblem(message: "is not UTF-8 text")])
        }
        let locator = JSONLocator(text)
        if let error = locator.syntaxError {
            return WidgetCheck(
                manifest: nil, problems: [WidgetProblem(line: error.line, message: error.message)])
        }
        let manifest: WidgetManifest
        do {
            manifest = try JSONDecoder().decode(WidgetManifest.self, from: data)
        } catch let error as DecodingError {
            let (path, message) = describe(error)
            return WidgetCheck(
                manifest: nil,
                problems: [WidgetProblem(line: locator.line(for: path), message: message)])
        } catch {
            return WidgetCheck(
                manifest: nil, problems: [WidgetProblem(message: error.localizedDescription)])
        }
        var ordered = manifest
        ordered.settingsOrder = locator.keys(at: ["settings"])
        var findings = ordered.findings(folder: folder)
        findings += unknownKeys(in: ordered, locator: locator)
        let problems =
            findings
            .map { WidgetProblem(line: locator.line(for: $0.path), message: $0.message) }
            .sorted { ($0.line ?? 0) < ($1.line ?? 0) }
        return WidgetCheck(manifest: ordered, problems: problems)
    }

    /// What is wrong with a bar component's edits to this widget's look and
    /// click, in the words `macarchy widget check` uses.
    public func problems(style: WidgetStyle?, click: WidgetClick?) -> [String] {
        let found = (style?.findings() ?? []) + (click?.findings(settings: settings ?? [:]) ?? [])
        return found.map(\.message)
    }

    /// Problems with a widget instance's saved settings, such as a setting
    /// the widget no longer has or a value of the wrong kind.
    public func problems(settings values: [String: SettingValue]) -> [String] {
        let declared = settings ?? [:]
        var problems: [String] = []
        for key in values.keys.sorted() {
            guard let value = values[key] else { continue }
            guard let setting = declared[key] else {
                problems.append("\(key) is not a setting of \(name)")
                continue
            }
            if let message = setting.mismatch(value) { problems.append("\(key) \(message)") }
        }
        return problems
    }
}

extension WidgetManifest {
    static func describe(_ error: DecodingError) -> (path: [String], message: String) {
        func names(_ path: [any CodingKey]) -> [String] {
            path.map { $0.intValue.map(String.init) ?? $0.stringValue }
        }
        func dotted(_ path: [String]) -> String {
            path.isEmpty ? "the document" : path.joined(separator: ".")
        }
        switch error {
        case .keyNotFound(let key, let context):
            let path = names(context.codingPath) + [key.stringValue]
            return (names(context.codingPath), "\(dotted(path)) is missing")
        case .typeMismatch(let type, let context), .valueNotFound(let type, let context):
            let path = names(context.codingPath)
            return (path, "\(dotted(path)) should be \(kind(of: type))")
        case .dataCorrupted(let context):
            let path = names(context.codingPath)
            return (path, "\(dotted(path)) could not be read: \(context.debugDescription)")
        @unknown default:
            return ([], error.localizedDescription)
        }
    }

    private static func kind(of type: Any.Type) -> String {
        switch type {
        case is String.Type: "text in quotes"
        case is Int.Type: "a whole number"
        case is Double.Type: "a number"
        case is Bool.Type: "true or false"
        case is SettingValue.Type: "text, a number, or true or false"
        default:
            String(describing: type).hasPrefix("Array") ? "a list" : "an object"
        }
    }

    /// Keys nothing reads, usually a typo of one that something does.
    static func unknownKeys(in manifest: WidgetManifest, locator: JSONLocator) -> [WidgetFinding] {
        var found: [WidgetFinding] = []
        func check(_ path: [String], allowed: [String]) {
            for key in locator.keys(at: path) where !allowed.contains(key) {
                let suggestion = closest(key, in: allowed).map { "; did you mean \($0)?" } ?? ""
                found.append(
                    WidgetFinding(
                        path + [key],
                        "\(key) is not something a widget.json can contain\(suggestion)"))
            }
        }
        check([], allowed: CodingKeys.allCases.map(\.rawValue))
        check(["style"], allowed: WidgetStyle.CodingKeys.allCases.map(\.rawValue))
        check(["update"], allowed: WidgetUpdate.CodingKeys.allCases.map(\.rawValue))
        check(["click"], allowed: WidgetClick.CodingKeys.allCases.map(\.rawValue))
        check(["samples"], allowed: WidgetSamples.CodingKeys.allCases.map(\.rawValue))
        for key in manifest.settings?.keys.sorted() ?? [] {
            check(["settings", key], allowed: WidgetSetting.CodingKeys.allCases.map(\.rawValue))
        }
        for index in (manifest.click?.dropdown ?? []).indices {
            check(
                ["click", "dropdown", String(index)],
                allowed: WidgetMenuRow.CodingKeys.allCases.map(\.rawValue))
        }
        return found
    }

    /// The allowed key a typo most likely meant, within two edits.
    private static func closest(_ key: String, in allowed: [String]) -> String? {
        allowed.map { ($0, distance(key.lowercased(), $0.lowercased())) }
            .filter { $0.1 <= 2 }
            .min { $0.1 < $1.1 }?.0
    }

    private static func distance(_ a: String, _ b: String) -> Int {
        let a = Array(a)
        let b = Array(b)
        var previous = Array(0...b.count)
        for (row, x) in a.enumerated() {
            var current = [row + 1]
            for (column, y) in b.enumerated() {
                current.append(
                    min(
                        previous[column + 1] + 1, current[column] + 1,
                        previous[column] + (x == y ? 0 : 1)))
            }
            previous = current
        }
        return previous[b.count]
    }
}
