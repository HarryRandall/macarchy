import AppKit
import Foundation
import Macarchy

extension BridgeRouter {
    /// The widget library's files: showing a folder, opening one of its
    /// files, and copying a built-in into the person's widgets to edit.
    func registerMenuBarWidgets(model: AppModel) {
        register("menuBar.revealWidget") { (params: WidgetFolderParams) in
            let folder: URL
            if let id = params.widget {
                guard let entry = WidgetCatalogue().read().entry(id) else {
                    throw BridgeFailure(.invalidParams, "There is no widget called \(id).")
                }
                folder = entry.directory
            } else {
                folder = Paths.widgetsDirectory
                try FileManager.default.createDirectory(
                    at: folder, withIntermediateDirectories: true)
            }
            NSWorkspace.shared.activateFileViewerSelecting([folder])
            return Null()
        }
        register("menuBar.openWidgetFile") { (params: WidgetFileParams) in
            guard let entry = WidgetCatalogue().read().entry(params.widget),
                MenuBarWidgets.files(in: entry.directory).contains(params.file)
            else { throw BridgeFailure(.invalidParams, "That file is not in the widget.") }
            let file = entry.directory.appending(path: params.file)
            let editor = NSWorkspace.shared.urlForApplication(toOpen: .plainText)
            if let editor {
                _ = try await NSWorkspace.shared.open(
                    [file], withApplicationAt: editor, configuration: .init())
            } else {
                NSWorkspace.shared.open(file)
            }
            return Null()
        }
        register("menuBar.duplicateWidget") { [weak model] (params: WidgetParams) in
            guard let model else { throw BridgeFailure(.unavailable, "The app is closing.") }
            let catalogue = WidgetCatalogue()
            guard let entry = catalogue.read().entry(params.widget) else {
                throw BridgeFailure(.invalidParams, "There is no widget called \(params.widget).")
            }
            let id = try MenuBarWidgets.duplicate(entry, catalogue: catalogue)
            return WidgetDuplicateResult(state: await model.readMenuBar(), widget: id)
        }
    }
}

enum MenuBarWidgets {
    /// Every widget the catalogue can read, in the order it lists them.
    static func info(_ catalogue: WidgetCatalogue = WidgetCatalogue()) -> [WidgetInfo] {
        catalogue.read().entries.map(info)
    }

    static func info(_ entry: WidgetCatalogue.Entry) -> WidgetInfo {
        let manifest = entry.manifest
        let text =
            (try? String(
                contentsOf: entry.directory.appending(path: "widget.json"), encoding: .utf8)) ?? ""
        return WidgetInfo(
            id: entry.id, name: manifest.name, description: manifest.description,
            author: manifest.author, version: manifest.version, icon: manifest.icon,
            origin: entry.origin.rawValue, scripted: manifest.isScripted,
            folder: (entry.directory.path as NSString).abbreviatingWithTildeInPath,
            files: files(in: entry.directory), manifest: text, label: manifest.label,
            source: manifest.source, provider: manifest.provider,
            settings: manifest.orderedSettings.map { key, setting in
                WidgetSettingInfo(
                    key: key, type: setting.type, label: setting.label,
                    default: setting.default, options: setting.options, min: setting.min,
                    max: setting.max, step: setting.step, unit: setting.unit, hint: setting.hint)
            },
            style: manifest.style, click: manifest.click, update: manifest.update,
            samples: manifest.samples)
    }

    /// The visible files in a widget's folder, by name.
    static func files(in folder: URL) -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return names.filter { !$0.hasPrefix(".") }.sorted()
    }

    /// Copies a widget into the person's widgets under an id no other widget
    /// has, and names the copy as one. Returns the copy's id.
    static func duplicate(
        _ entry: WidgetCatalogue.Entry, catalogue: WidgetCatalogue
    ) throws -> String {
        let id = WidgetCatalogue.unusedID(from: "\(entry.id)-copy", taken: catalogue.takenIDs())
        let destination = catalogue.user.appending(path: id)
        try FileManager.default.createDirectory(
            at: catalogue.user, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: entry.directory, to: destination)
        let file = destination.appending(path: "widget.json")
        var text = try String(contentsOf: file, encoding: .utf8)
        text = renamed(text, key: "id", to: id)
        text = renamed(text, key: "name", to: "\(entry.manifest.name) copy")
        try text.write(to: file, atomically: true, encoding: .utf8)
        return id
    }

    /// `text` with the first `"key": "…"` given a new value, leaving the rest
    /// of the file as it was written.
    static func renamed(_ text: String, key: String, to value: String) -> String {
        let pattern = "\"\(key)\"\\s*:\\s*\"(?:[^\"\\\\]|\\\\.)*\""
        guard let range = text.range(of: pattern, options: .regularExpression) else { return text }
        let escaped = value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return text.replacingCharacters(in: range, with: "\"\(key)\": \"\(escaped)\"")
    }
}
