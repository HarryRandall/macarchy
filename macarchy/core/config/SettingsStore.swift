import Foundation
import Darwin

public enum SettingValue: Codable, Sendable, Equatable {
    case number(Double)
    case bool(Bool)
    case text(String)
    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if let boolean = try? value.decode(Bool.self) {
            self = .bool(boolean)
        } else if let number = try? value.decode(Double.self) {
            self = .number(number)
        } else {
            self = .text(try value.decode(String.self))
        }
    }
    public func encode(to encoder: Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self {
        case .number(let number): try value.encode(number)
        case .bool(let boolean): try value.encode(boolean)
        case .text(let text): try value.encode(text)
        }
    }
    public var string: String {
        switch self {
        case .number(let number):
            if number.rounded() == number { String(format: "%.0f", number) } else { String(number) }
        case .bool(let boolean): boolean ? "true" : "false"
        case .text(let text): text
        }
    }
}

public struct SettingsDocument: Codable, Sendable, Equatable {
    public var schema = 1
    public var currentTheme: String?
    public var wallpapers: [String: String] = [:]
    public var layout: [String: SettingValue] = [:]
    public var borders: [String: SettingValue] = [:]
    public var menuBar: [String: SettingValue] = [:]
    public var floatingApps: [String] = []
    public var windowRules: [CustomWindowRule]?
    public var barConfiguration: BarConfiguration?
    public var itemOrder: [String] = []
    public var itemVisibility: [String: Bool] = [:]
    public var itemLabels: [String: String] = [:]
    /// False when setup kept the person's existing bar instead of Macarchy's.
    public var bundledBar: Bool?
    public init() {}

    public func validate() throws {
        try barConfiguration?.validate()
        let rules = windowRules ?? []
        guard Set(rules.map(\.id)).count == rules.count else {
            throw ConfigurationError("Window rule identifiers must be unique")
        }
        for rule in rules { try rule.validate() }
        guard schema == 1 else { throw ConfigurationError("Unsupported settings schema") }
        let numeric = [layout, borders, menuBar].flatMap { $0.values }
        for value in numeric {
            if case .number(let number) = value, !number.isFinite {
                throw ConfigurationError("Settings contain a non-finite number")
            }
        }
        if let currentTheme {
            guard
                currentTheme.range(of: "^[a-zA-Z0-9][a-zA-Z0-9_-]*$", options: .regularExpression)
                    != nil
            else {
                throw ConfigurationError("Invalid active theme name")
            }
        }
        for path in wallpapers.values
        where path.hasPrefix("/") || path.split(separator: "/").contains("..") {
            throw ConfigurationError("Wallpaper paths must stay inside their theme")
        }
        let ranges: [String: ClosedRange<Double>] = [
            "BORDER_WIDTH": 0...16, "YABAI_WINDOW_GAP": 0...1000,
            "YABAI_TOP_PADDING": 0...1000, "YABAI_BOTTOM_PADDING": 0...1000,
            "YABAI_LEFT_PADDING": 0...1000, "YABAI_RIGHT_PADDING": 0...1000,
            "SKETCHYBAR_HEIGHT": 1...200, "SKETCHYBAR_BLUR_RADIUS": 0...100
        ]
        for (key, range) in ranges {
            if let raw = flatValues[key] {
                guard let number = Double(raw), number.isFinite, range.contains(number) else {
                    throw ConfigurationError("\(key) is outside its supported range")
                }
            }
        }
    }

    /// Settings keyed the way integrations consume them, such as `YABAI_WINDOW_GAP`.
    public var flatValues: [String: String] {
        var result: [String: String] = [:]
        for (prefix, values) in [("YABAI_", layout), ("", borders), ("SKETCHYBAR_", menuBar)] {
            for (key, value) in values {
                let name = prefix + key.uppercased()
                if case .bool(let flag) = value, name != "BORDERS_VISIBLE" {
                    result[name] = flag ? "on" : "off"
                } else {
                    result[name] = value.string
                }
            }
        }
        return result
    }

    public mutating func mergeFlat(_ values: [String: String]) {
        for (key, raw) in values {
            let value: SettingValue
            if ["true", "false", "on", "off"].contains(raw) {
                value = .bool(raw == "true" || raw == "on")
            } else if let number = Double(raw), number.isFinite {
                value = .number(number)
            } else {
                value = .text(raw)
            }
            if key.hasPrefix("YABAI_") {
                layout[String(key.dropFirst(6)).lowercased()] = value
            } else if key.hasPrefix("SKETCHYBAR_") {
                menuBar[String(key.dropFirst(11)).lowercased()] = value
            } else if key.hasPrefix("BORDER") {
                borders[key.lowercased()] = value
            }
        }
    }
}

public struct ConfigurationError: LocalizedError {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}

/// JSON is authoritative. A missing file reads as defaults; setup creates it.
public struct SettingsStore: Sendable {
    public let url: URL
    public init(url: URL = Paths.settings) { self.url = url }

    public func read() throws -> SettingsDocument {
        guard FileManager.default.fileExists(atPath: url.path) else { return SettingsDocument() }
        let settings = try JSONDecoder().decode(SettingsDocument.self, from: Data(contentsOf: url))
        guard settings.schema == 1 else {
            throw ConfigurationError("Unsupported settings schema: \(settings.schema)")
        }
        try settings.validate()
        return settings
    }

    public func load() throws -> [String: String] { try read().flatValues }
    public func set(_ key: String, _ value: String) throws {
        try update { $0.mergeFlat([key: value]) }
    }
    public func write(_ values: [String: String]) throws { try update { $0.mergeFlat(values) } }

    /// The app and CLI may write at the same time. Lock the whole read-modify-write.
    public func update(_ edit: (inout SettingsDocument) throws -> Void) throws {
        try FileLock.withLock(url) { try updateLocked(edit) }
    }

    private func updateLocked(_ edit: (inout SettingsDocument) throws -> Void) throws {
        var settings = try read()
        try edit(&settings)
        try settings.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(settings)
        if (try? Data(contentsOf: url)) == data { return }
        try SnapshotStore(root: url.deletingLastPathComponent().appending(path: "snapshots"))
            .capture([url], reason: "settings changed")
        try data.write(to: url, options: .atomic)
    }
}
