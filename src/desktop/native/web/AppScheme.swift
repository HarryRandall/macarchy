import Foundation
import Macarchy
import UniformTypeIdentifiers
import WebKit

/// Serves the interface and its images from `macarchy-app://`.
///
/// `macarchy-app://ui/<file>` reads the built interface: the app bundle's
/// `Resources/ui`, or `MACARCHY_UI_DIST` when set, so tests and unbundled
/// builds can point at `src/desktop/ui/dist`. A custom scheme rather than
/// `file://` gives the page a real origin, which module scripts need.
///
/// `macarchy-app://media/...` returns downsampled JPEGs of theme wallpapers.
/// Only files the resolver vouches for are read; the page cannot name an
/// arbitrary path.
@MainActor
final class AppScheme: NSObject, WKURLSchemeHandler {
    nonisolated static let scheme = "macarchy-app"

    /// Maps a media URL to the image file it stands for, or nil to refuse it.
    var resolveMedia: @MainActor (URL) -> URL? = { _ in nil }

    private var stopped: Set<ObjectIdentifier> = []

    nonisolated static var interfaceRoot: URL? {
        if let override = ProcessInfo.processInfo.environment["MACARCHY_UI_DIST"] {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        return Bundle.main.resourceURL?.appending(path: "ui", directoryHint: .isDirectory)
    }

    nonisolated static func pageURL(_ surface: Surface) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "ui"
        components.path = "/\(surface.rawValue).html"
        guard let url = components.url else { preconditionFailure("Invalid interface URL") }
        return url
    }

    func webView(_ webView: WKWebView, start task: any WKURLSchemeTask) {
        stopped.remove(ObjectIdentifier(task))
        guard let url = task.request.url else {
            return fail(task, 400)
        }
        switch url.host() {
        case "ui": serveInterface(url, task)
        case "media": serveMedia(url, task)
        default: fail(task, 404)
        }
    }

    func webView(_ webView: WKWebView, stop task: any WKURLSchemeTask) {
        stopped.insert(ObjectIdentifier(task))
    }

    private func serveInterface(_ url: URL, _ task: any WKURLSchemeTask) {
        guard let root = Self.interfaceRoot?.standardizedFileURL else { return fail(task, 404) }
        let relative = url.path().removingPercentEncoding ?? url.path()
        let file = root.appending(path: relative).standardizedFileURL
        guard file.path.hasPrefix(root.path + "/"),
            let data = try? Data(contentsOf: file)
        else { return fail(task, 404) }
        let type = Self.mimeType(for: file)
        var headers = ["Content-Type": type, "Cache-Control": "no-cache"]
        if type.hasPrefix("text/html") {
            // The page only ever needs its own scripts and styles and the
            // media this handler serves.
            headers["Content-Security-Policy"] =
                "default-src 'self'; img-src 'self' \(Self.scheme): data:; "
                + "style-src 'self' 'unsafe-inline'; script-src 'self'; connect-src 'self'"
        }
        respond(task, url: url, status: 200, headers: headers, data: data)
    }

    private func serveMedia(_ url: URL, _ task: any WKURLSchemeTask) {
        guard let file = resolveMedia(url) else { return fail(task, 404) }
        let maxPixels =
            URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
            .first { $0.name == "max" }?.value.flatMap(Int.init).map { min(max($0, 64), 2400) }
            ?? 1400
        let id = ObjectIdentifier(task)
        Task {
            let data = await Thumbnails.shared.jpeg(for: file, maxPixels: maxPixels)
            guard !stopped.contains(id) else { return }
            guard let data else { return fail(task, 404) }
            respond(
                task, url: url, status: 200,
                headers: ["Content-Type": "image/jpeg", "Cache-Control": "max-age=3600"],
                data: data)
        }
    }

    private func respond(
        _ task: any WKURLSchemeTask, url: URL, status: Int, headers: [String: String], data: Data
    ) {
        guard !stopped.contains(ObjectIdentifier(task)) else { return }
        var headers = headers
        headers["Content-Length"] = String(data.count)
        guard
            let response = HTTPURLResponse(
                url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)
        else { return task.didFailWithError(URLError(.cannotParseResponse)) }
        task.didReceive(response)
        task.didReceive(data)
        task.didFinish()
    }

    private func fail(_ task: any WKURLSchemeTask, _ status: Int) {
        guard let url = task.request.url else {
            task.didFailWithError(URLError(.badURL))
            return
        }
        respond(
            task, url: url, status: status, headers: ["Content-Type": "text/plain"], data: Data())
    }

    nonisolated static func mimeType(for file: URL) -> String {
        switch file.pathExtension.lowercased() {
        case "html": "text/html; charset=utf-8"
        case "js", "mjs": "text/javascript; charset=utf-8"
        case "css": "text/css; charset=utf-8"
        case "json", "map": "application/json"
        case "svg": "image/svg+xml"
        default:
            UTType(filenameExtension: file.pathExtension)?.preferredMIMEType
                ?? "application/octet-stream"
        }
    }

    // MARK: - Media URLs

    /// A thumbnail of an image inside a theme folder.
    nonisolated static func themeImageURL(theme: String, path: String, maxPixels: Int) -> String {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "media"
        components.path = "/theme/\(theme)/\(path)"
        components.queryItems = [URLQueryItem(name: "max", value: String(maxPixels))]
        return components.string ?? ""
    }

    /// The wallpaper behind the Layout preview. `version` changes with the file,
    /// so WebKit never shows a cached image for a different wallpaper.
    nonisolated static func wallpaperURL(file: URL, maxPixels: Int) -> String {
        let modified =
            (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate?.timeIntervalSince1970 ?? 0
        let version = String(format: "%08x", (file.path + "\(modified)").hashValue & 0xFFFF_FFFF)
        return "\(scheme)://media/wallpaper?max=\(maxPixels)&v=\(version)"
    }

    /// Resolves `/theme/<name>/<path>` inside the themes folder, refusing
    /// anything that would leave the theme.
    nonisolated static func themeImage(
        for url: URL, themesDirectory: URL = Paths.themesDirectory
    ) -> URL? {
        let parts = (url.path().removingPercentEncoding ?? url.path())
            .split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard parts.count >= 3, parts[0] == "theme", !parts.contains(".."), !parts.contains(".")
        else { return nil }
        // Links are followed before the containment check, so a link inside a
        // theme cannot hand out a file from elsewhere.
        let theme = themesDirectory.appending(path: parts[1]).resolvingSymlinksInPath()
        let file = theme.appending(path: parts[2...].joined(separator: "/"))
            .resolvingSymlinksInPath()
        let images: Set<String> = ["png", "jpg", "jpeg", "heic", "webp"]
        guard theme.path.hasPrefix(themesDirectory.resolvingSymlinksInPath().path + "/"),
            file.path.hasPrefix(theme.path + "/"),
            images.contains(file.pathExtension.lowercased()),
            FileManager.default.fileExists(atPath: file.path)
        else { return nil }
        return file
    }
}
