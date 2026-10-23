import Foundation

/// Keeps the bar's widgets up to date.
///
/// The app runs one host. Each widget is worked out when it is due, by its
/// interval or a system event; everything due at once runs together, and the
/// changes go to SketchyBar in one call, with values that did not change left
/// out, since every `--set` repaints. A provider that fails or hangs leaves the
/// last thing it showed in place and records why in `problems`.
public actor WidgetHost {
    /// A reading Macarchy provides itself, by `source` name.
    public typealias Source = @Sendable (WidgetInstance, Date) async -> WidgetOutput?
    /// The readings named in `WidgetManifest.sources`. Each one is added
    /// here with the built-in widget that uses it.
    public static let builtInSources: [String: Source] = [:]
    /// Where the host reads the bar and the widgets from.
    public typealias Load = @Sendable () -> (BarConfiguration?, WidgetCatalogue.Snapshot)

    private let integrations: Integrations
    private let runner: WidgetProviderRunner
    private let sources: [String: Source]
    private let load: Load
    private let store: SettingsStore

    public private(set) var instances: [WidgetInstance] = []
    /// Why a widget is not showing what it should, by instance id.
    public private(set) var problems: [String: String] = [:]
    private var due: [String: Date] = [:]
    private var lastGood: [String: WidgetOutput] = [:]
    private var sent: [String: [String]] = [:]
    private var loop: Task<Void, Never>?
    private var components: [String: BarComponent] = [:]

    public init(
        integrations: Integrations = Integrations(), runner: WidgetProviderRunner = .init(),
        sources: [String: Source] = WidgetHost.builtInSources, load: Load? = nil,
        store: SettingsStore = SettingsStore()
    ) {
        self.store = store
        self.integrations = integrations
        self.runner = runner
        self.sources = sources
        self.load =
            load ?? {
                (try? BarConfigurationStore().load(), WidgetCatalogue().read())
            }
    }

    // MARK: - Running

    /// Updates widgets as they fall due until `stop`.
    public func start() {
        loop?.cancel()
        reload()
        loop = Task { await self.run() }
    }

    public func stop() {
        loop?.cancel()
        loop = nil
    }

    /// Reads the bar and widgets again and updates every widget straight
    /// away, as after an edit on the Menu Bar page.
    public func restart() {
        guard loop != nil else { return reload() }
        start()
    }

    private func run() async {
        while !Task.isCancelled {
            _ = await update(now: Date())
            let wait = nextDue().map { $0.timeIntervalSinceNow } ?? 3600
            try? await Task.sleep(for: .seconds(min(max(wait, 0.05), 3600)))
        }
    }

    // MARK: - Steps

    /// Reads the bar and widgets, and makes every widget due now.
    public func reload(now: Date = Date()) {
        let (configuration, catalogue) = load()
        let resolved = WidgetInstance.resolve(configuration, catalogue: catalogue)
        instances = resolved.instances
        problems = resolved.problems
        components = Dictionary(
            (configuration?.components ?? []).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first })
        let ids = Set(instances.map(\.id))
        due = Dictionary(uniqueKeysWithValues: instances.map { ($0.id, now) })
        lastGood = lastGood.filter { ids.contains($0.key) }
        sent = sent.filter { ids.contains($0.key) }
    }

    /// Works out every widget that is due and sends what changed.
    @discardableResult
    public func update(now: Date = Date()) async -> CommandResult? {
        let ids = instances.filter { (due[$0.id] ?? .distantFuture) <= now }.map(\.id)
        return await refresh(Set(ids), now: now)
    }

    /// Updates the widgets that asked to hear about `event`. Waking from
    /// sleep updates them all, since every interval ran on while asleep.
    @discardableResult
    public func trigger(_ event: String, now: Date = Date()) async -> CommandResult? {
        let ids = instances.filter {
            event == "system_woke" || ($0.manifest.update?.events ?? []).contains(event)
        }
        return await refresh(Set(ids.map(\.id)), now: now)
    }

    /// Works out the given widgets now, whether or not they are due.
    @discardableResult
    public func refresh(_ ids: Set<String>? = nil, now: Date = Date()) async -> CommandResult? {
        let targets = instances.filter { $0.visible && (ids?.contains($0.id) ?? true) }
        let runner = self.runner
        let sources = self.sources
        let results = await withTaskGroup(of: (String, Result<WidgetOutput, Failure>).self) {
            group in
            for instance in targets {
                group.addTask {
                    (
                        instance.id,
                        await Self.produce(instance, now: now, runner: runner, sources: sources)
                    )
                }
            }
            var collected: [String: Result<WidgetOutput, Failure>] = [:]
            for await (id, result) in group { collected[id] = result }
            return collected
        }
        var arguments: [String] = []
        for instance in targets {
            switch results[instance.id] {
            case .success(let output):
                lastGood[instance.id] = output
                problems[instance.id] = nil
            case .failure(let failure):
                problems[instance.id] = failure.message
            case nil: break
            }
            due[instance.id] = Self.next(after: now, every: instance.manifest.update?.every)
            let properties = Self.properties(instance, output: lastGood[instance.id])
            if sent[instance.id] != properties {
                arguments += ["--set", instance.id] + properties
            }
        }
        guard !arguments.isEmpty else { return nil }
        let result = await integrations.sketchybar(arguments)
        if result.ok {
            for instance in targets {
                sent[instance.id] = Self.properties(instance, output: lastGood[instance.id])
            }
        } else {
            // An item SketchyBar no longer has, after it restarted, fails the
            // whole call. Send everything again next time, once startup has
            // put the items back.
            sent.removeAll()
        }
        return result
    }

    /// When the next widget falls due, or nil when none has an interval.
    public func nextDue() -> Date? {
        instances.filter(\.visible).compactMap { due[$0.id] }.min()
    }

    // MARK: - Dropdowns

    /// The rows of a widget's dropdown as they stand now, or nil when the
    /// widget is not on the bar.
    public func menu(for id: String) -> [WidgetMenuItem]? {
        guard let instance = instances.first(where: { $0.id == id }) else { return nil }
        let output = lastGood[id]
        return WidgetMenu.items(
            instance: instance, component: components[id], output: output,
            label: Self.clean(Self.label(instance, output: output)))
    }

    /// Carries out picking a row, and says what it did so the dropdown can
    /// close or stay open. A setting is saved, and the widget redrawn with it.
    @discardableResult
    public func pick(
        _ row: Int, option: String? = nil, in id: String, execute: WidgetActions.Execute? = nil
    ) async throws -> WidgetMenu.Effect {
        guard let instance = instances.first(where: { $0.id == id }) else {
            throw ConfigurationError("There is no widget called \(id) on the bar")
        }
        let effect = WidgetMenu.effect(
            of: row, option: option, instance: instance, component: components[id],
            output: lastGood[id])
        switch effect {
        case .open(let target): try await WidgetActions.open(target, execute: execute)
        case .run(let command):
            try await WidgetActions.run(command, for: instance, execute: execute)
        case .set(let key, let value):
            try WidgetMenu.save(key, value, instance: id, store: store)
            reload()
            await refresh([id])
        case .nothing: break
        }
        return effect
    }

    // MARK: - Working out a widget

    struct Failure: Error, Equatable {
        let message: String
    }

    private static func produce(
        _ instance: WidgetInstance, now: Date, runner: WidgetProviderRunner,
        sources: [String: Source]
    ) async -> Result<WidgetOutput, Failure> {
        let manifest = instance.manifest
        if let source = manifest.source {
            guard let read = sources[source] else {
                return .failure(Failure(message: "The \(source) reading is not available yet"))
            }
            guard let output = await read(instance, now) else {
                return .failure(Failure(message: "The \(source) reading could not be taken"))
            }
            return .success(output)
        }
        if let provider = manifest.provider {
            return await runner.run(
                provider: provider, in: instance.directory, instance: instance.id,
                widget: manifest.id, settings: instance.settings
            ).mapError { Failure(message: "\(provider) \($0)") }
        }
        return .success(WidgetOutput())
    }

    /// What the widget's item is set to for an output, or its unavailable
    /// sample when there has never been one.
    static func properties(_ instance: WidgetInstance, output: WidgetOutput?) -> [String] {
        let shown = clean(label(instance, output: output))
        var properties = ["label=\(shown)", "label.drawing=\(shown.isEmpty ? "off" : "on")"]
        if let icon = output?.icon {
            let glyph = clean(icon)
            properties += ["icon=\(glyph)", "icon.drawing=\(glyph.isEmpty ? "off" : "on")"]
        }
        if let colour = output?.colour.flatMap(WidgetColour.sketchybar) {
            properties.append("label.color=\(colour)")
        }
        if let colour = output?.iconColour.flatMap(WidgetColour.sketchybar) {
            properties.append("icon.color=\(colour)")
        }
        properties.append("drawing=\(output?.drawing == false ? "off" : "on")")
        return properties
    }

    /// The label for an output, or the unavailable sample when there has never been one.
    static func label(_ instance: WidgetInstance, output: WidgetOutput?) -> String {
        guard let output else { return instance.manifest.samples?.unavailable ?? "--" }
        let values = instance.settings.mapValues(\.string).merging(output.values) { $1 }
        return output.label
            ?? WidgetTemplate.render(instance.manifest.label ?? "", values: values)
    }

    /// One line, no control characters, and short enough for a bar.
    static func clean(_ text: String) -> String {
        let line = text.unicodeScalars.map { scalar -> String in
            CharacterSet.newlines.contains(scalar)
                ? " "
                : CharacterSet.controlCharacters.contains(scalar) ? "" : String(scalar)
        }.joined()
        return String(line.trimmingCharacters(in: .whitespaces).prefix(200))
    }

    /// The next time a widget updating `every` falls due. Boundaries such as
    /// `minute` land on the boundary, as a clock should.
    static func next(after now: Date, every: String?) -> Date? {
        guard let every, let seconds = WidgetUpdate(every: every).seconds else { return nil }
        if every == "minute" || every == "second" {
            let step = Double(seconds)
            return Date(
                timeIntervalSince1970: (floor(now.timeIntervalSince1970 / step) + 1) * step)
        }
        return now.addingTimeInterval(Double(seconds))
    }
}
