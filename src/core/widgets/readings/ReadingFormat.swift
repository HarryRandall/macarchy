import Foundation

/// How built-in readings are written on the bar and in dropdowns. Each
/// keeps a fixed shape, so a widget's width does not jump as values change.
enum ReadingFormat {
    /// `12.3%`.
    static func percent(_ value: Double) -> String {
        String(format: "%.1f%%", min(max(value, 0), 100))
    }

    /// `12%`.
    static func wholePercent(_ value: Double) -> String {
        String(format: "%.0f%%", min(max(value, 0), 100))
    }

    /// `47.3°`, or `--` with no reading.
    static func degrees(_ value: Double?) -> String {
        value.map { String(format: "%.1f°", $0) } ?? "--"
    }

    /// `9.8G`, or `512M` under a gigabyte, for the bar.
    static func bytes(_ value: UInt64) -> String {
        let gigabytes = Double(value) / 1_073_741_824
        if gigabytes >= 1 { return String(format: "%.1fG", gigabytes) }
        return String(format: "%.0fM", Double(value) / 1_048_576)
    }

    /// `9.8 GB`, for dropdowns.
    static func bytesLong(_ value: UInt64) -> String {
        let text = bytes(value)
        return String(text.dropLast()) + " " + String(text.suffix(1)) + "B"
    }

    /// `1.2MB/s`, or `512KB/s` under a megabyte a second.
    static func rate(_ bytesPerSecond: Double) -> String {
        let megabytes = max(bytesPerSecond, 0) / 1_048_576
        if megabytes >= 1 { return String(format: "%.1fMB/s", min(megabytes, 999.9)) }
        return String(format: "%.0fKB/s", max(bytesPerSecond, 0) / 1024)
    }

    /// `3:12` from minutes.
    static func duration(_ minutes: Int) -> String {
        String(format: "%d:%02d", minutes / 60, minutes % 60)
    }

    /// Points for a dropdown graph, oldest first.
    static func history(_ values: [Double]) -> String {
        values.map { String(format: "%.1f", $0) }.joined(separator: ",")
    }

    /// The colour a reading takes once it passes `warn`, and red past `alarm`.
    static func warning(_ value: Double?, warn: Double, alarm: Double) -> String? {
        guard let value else { return nil }
        if value >= alarm { return "#f87171" }
        return value >= warn ? "#fbbf24" : nil
    }
}

/// The busiest apps, with helper processes counted towards their app, as
/// the Battery and CPU menus group them.
struct TopProcesses: Equatable, Sendable {
    struct Entry: Equatable, Sendable {
        var name: String
        var cpu: Double
        var memory: UInt64
    }

    var entries: [Entry]

    /// Reads `ps`, which every Mac has, so nothing extra is needed.
    static func read() async -> TopProcesses {
        let result = await CommandRunner.run(
            "/bin/ps", ["-Aceo", "pcpu=,rss=,comm="], timeout: 2)
        return parse(result.ok ? result.stdout : "")
    }

    static func parse(_ text: String) -> TopProcesses {
        var grouped: [String: Entry] = [:]
        for line in text.split(separator: "\n") {
            let fields = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard fields.count == 3, let cpu = Double(fields[0]), let rss = UInt64(fields[1])
            else { continue }
            let name = appName(String(fields[2]))
            var entry = grouped[name] ?? Entry(name: name, cpu: 0, memory: 0)
            entry.cpu += cpu
            entry.memory += rss * 1024
            grouped[name] = entry
        }
        return TopProcesses(entries: Array(grouped.values))
    }

    /// `Firefox GPU Helper` and `Claude Helper (Renderer)` as their app.
    static func appName(_ process: String) -> String {
        guard let range = process.range(of: " Helper") else { return process }
        let name = String(process[..<range.lowerBound])
        return name.hasSuffix(" GPU") ? String(name.dropLast(4)) : name
    }

    /// `Name:12.3%,…` for the busiest three by CPU.
    func byCPU(_ count: Int = 3) -> String {
        entries.sorted { $0.cpu > $1.cpu }.prefix(count)
            .map { "\($0.name):\(String(format: "%.1f%%", $0.cpu))" }.joined(separator: ",")
    }

    /// `Name:1.2 GB,…` for the three using the most memory.
    func byMemory(_ count: Int = 3) -> String {
        entries.sorted { $0.memory > $1.memory }.prefix(count)
            .map { "\($0.name):\(ReadingFormat.bytesLong($0.memory))" }.joined(separator: ",")
    }
}
