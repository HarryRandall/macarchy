import AppKit
import Macarchy
import UniformTypeIdentifiers

extension BridgeRouter {
    func registerRules(
        model: AppModel,
        chooseApplication: @escaping @MainActor () -> String? = RulesPresentation.chooseApplication
    ) {
        register("rules.getState") { (_: Empty) in
            do { return try await model.readRulesState() } catch {
                model.log.failure("read rules", error.localizedDescription)
                throw BridgeFailure(.operationFailed, error.localizedDescription)
            }
        }
        register("rules.addApplication") { (_: Empty) in
            guard let app = chooseApplication() else { return Null() }
            return try await Self.editRules(model) {
                try await model.windowRuleSettings.setFloating(app: app, floating: true)
            }
        }
        register("rules.removeFloating") { (params: RemoveFloatingParams) in
            try await Self.editRules(model) {
                try await model.windowRuleSettings.setFloating(app: params.app, floating: false)
            }
        }
        register("rules.saveCustom") { (params: SaveRuleParams) in
            try await Self.editRules(model) {
                try await model.windowRuleSettings.save(
                    params.rule, existing: params.existing ?? false)
            }
        }
        register("rules.removeCustom") { (params: RemoveRuleParams) in
            try await Self.editRules(model) {
                try await model.windowRuleSettings.removeCustom(id: params.id)
            }
        }
    }

    private static func editRules(
        _ model: AppModel, operation: () async throws -> Void
    ) async throws -> Null {
        do {
            try await operation()
            model.log.record(CommandResult(command: "window rules", status: 0))
            await StateBroadcast.shared.rulesWritten(model)
            return Null()
        } catch {
            model.log.failure("Window rule failed", error.localizedDescription)
            throw BridgeFailure(.operationFailed, error.localizedDescription)
        }
    }
}

extension AppModel {
    var windowRuleSettings: WindowRuleSettings {
        WindowRuleSettings(store: settingsStore, integrations: backend)
    }

    func readRulesState() async throws -> RulesState {
        let snapshot = try await windowRuleSettings.read()
        let names = Set(
            snapshot.floatingApps + snapshot.customRules.map(\.app)
                + snapshot.externalRules.map(\.app))
        return RulesState(
            floatingApps: snapshot.floatingApps, customRules: snapshot.customRules,
            externalRules: snapshot.externalRules,
            icons: Dictionary(
                uniqueKeysWithValues: names.compactMap { name in
                    RulesPresentation.icon(name).map { (name, $0) }
                }),
            unavailableReason: snapshot.unavailableReason)
    }
}

@MainActor
enum RulesPresentation {
    static func chooseApplication() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Float"
        panel.message = "Choose an application yabai should leave untiled"
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return FileManager.default.displayName(atPath: url.path)
            .replacingOccurrences(of: ".app", with: "")
    }

    static func icon(_ name: String) -> String? {
        for root in [
            "/Applications", "/System/Applications", NSHomeDirectory() + "/Applications",
            "/System/Applications/Utilities"
        ] {
            let path = "\(root)/\(name).app"
            guard FileManager.default.fileExists(atPath: path),
                let tiff = NSWorkspace.shared.icon(forFile: path).tiffRepresentation,
                let bitmap = NSBitmapImageRep(data: tiff),
                let png = bitmap.representation(using: .png, properties: [:])
            else { continue }
            return "data:image/png;base64," + png.base64EncodedString()
        }
        return nil
    }
}
