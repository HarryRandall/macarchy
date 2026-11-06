import Foundation

/// The date and time as the Clock widget's settings ask for it, and the
/// pieces its label and dropdown use.
enum ClockReading {
    static func output(_ instance: WidgetInstance, now: Date) -> WidgetOutput {
        let settings = instance.settings
        let zone = text(settings["timeZone"]).flatMap(TimeZone.init(identifier:)) ?? .current
        let custom = text(settings["format"])
        let label = custom.map { strftime($0, now, zone) } ?? format(pattern(settings), now, zone)
        var values = [
            "date": label,
            "time": format(timePattern(settings), now, zone),
            "weekday": format("EEE", now, zone),
            "weekday.long": format("EEEE", now, zone),
            "day": format("d", now, zone),
            "month": format("MMM", now, zone),
            "month.long": format("MMMM", now, zone),
            "year": format("yyyy", now, zone),
            "zone": zone.localizedName(for: .shortGeneric, locale: .current) ?? zone.identifier
        ]
        for name in zonesAsked(instance) {
            if let other = TimeZone(identifier: name) {
                values["time:\(name)"] = format(timePattern(settings), now, other)
            }
        }
        return WidgetOutput(label: label, values: values)
    }

    /// The parts the settings turn on, in the order they ask for.
    static func pattern(_ settings: [String: SettingValue]) -> String {
        func on(_ key: String, _ fallback: Bool) -> Bool {
            if case .bool(let value) = settings[key] { return value }
            return fallback
        }
        let monthFirst = text(settings["order"]) == "month-day"
        let date =
            monthFirst
            ? [on("month", true) ? "MMM" : nil, on("day", true) ? "d" : nil]
            : [on("day", true) ? "d" : nil, on("month", true) ? "MMM" : nil]
        let parts =
            [on("weekday", true) ? "EEE" : nil] + date
            + [on("year", false) ? "yyyy" : nil, on("time", true) ? timePattern(settings) : nil]
        return parts.compactMap { $0 }.joined(separator: " ")
    }

    static func timePattern(_ settings: [String: SettingValue]) -> String {
        let twentyFour = settings["twentyFourHour"] == .bool(true)
        let lead = settings["leadingZero"] != .bool(false)
        let hour = twentyFour ? (lead ? "HH" : "H") : (lead ? "hh" : "h")
        let seconds = settings["seconds"] == .bool(true) ? ":ss" : ""
        return hour + ":mm" + seconds + (twentyFour ? "" : " a")
    }

    /// Time zones the dropdown's rows name, as `{time:Europe/London}`.
    static func zonesAsked(_ instance: WidgetInstance) -> [String] {
        let rows = instance.click?.dropdown ?? []
        let text = rows.flatMap { [$0.label ?? "", $0.value ?? ""] }.joined(separator: " ")
        var zones: [String] = []
        var rest = Substring(text)
        while let start = rest.range(of: "{time:") {
            rest = rest[start.upperBound...]
            guard let end = rest.firstIndex(of: "}") else { break }
            zones.append(String(rest[..<end]))
            rest = rest[end...]
        }
        return zones
    }

    private static func text(_ value: SettingValue?) -> String? {
        guard case .text(let text) = value, !text.trimmingCharacters(in: .whitespaces).isEmpty
        else { return nil }
        return text
    }

    private static func format(_ pattern: String, _ date: Date, _ zone: TimeZone) -> String {
        let formatter = DateFormatter()
        // A fixed copy of the locale, so the system's 24-hour switch does not
        // override the widget's own setting.
        formatter.locale = Locale(identifier: Locale.current.identifier)
        formatter.amSymbol = "AM"
        formatter.pmSymbol = "PM"
        formatter.timeZone = zone
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }

    /// A format written with strftime codes, as SketchyBar configs use.
    private static func strftime(_ format: String, _ date: Date, _ zone: TimeZone) -> String {
        var time = time_t(date.timeIntervalSince1970)
        var parts = tm()
        let offset = zone.secondsFromGMT(for: date)
        time += time_t(offset)
        gmtime_r(&time, &parts)
        var buffer = [CChar](repeating: 0, count: 128)
        let length = Darwin.strftime(&buffer, buffer.count, format, &parts)
        let bytes = buffer.prefix(length).map { UInt8(bitPattern: $0) }
        return String(bytes: bytes, encoding: .utf8) ?? ""
    }
}
