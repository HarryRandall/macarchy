import AppKit
import OSLog
import WebKit

/// One page of the React interface in a web view, with its bridge.
///
/// Requests arrive through the `macarchy` script message handler and are
/// answered by the surface's router. Events go the other way through
/// `window.macarchyBridge.receive`, which a document-start script defines
/// before any page script runs, so nothing sent while the page loads is lost.
@MainActor
final class WebSurface: NSObject {
    let surface: Surface
    let webView: HostWebView
    let router = BridgeRouter()
    let scheme = AppScheme()

    /// Called once per page load, when the page says it has rendered real data.
    var onReady: (() -> Void)?
    private(set) var isReady = false

    private var loaded = false
    private var readyWaiters: [Once] = []
    private var pending: [String] = []
    private let log = Logger(subsystem: "io.github.harryrandall.macarchy", category: "web")

    init(surface: Surface, transparent: Bool = false, keepsDrawingInactive: Bool = false) {
        self.surface = surface
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(scheme, forURLScheme: AppScheme.scheme)
        configuration.websiteDataStore = .nonPersistent()
        if keepsDrawingInactive {
            // The switcher's page renders while its panel is hidden or not
            // yet visible; it must not be throttled as a background page.
            configuration.preferences.inactiveSchedulingPolicy = .none
        }
        configuration.userContentController.addUserScript(
            WKUserScript(
                source:
                    "window.macarchyBridge = { queue: [], receive(event) { this.queue.push(event) } };",
                injectionTime: .atDocumentStart, forMainFrameOnly: true))
        webView = HostWebView(frame: .zero, configuration: configuration)
        super.init()

        configuration.userContentController.addScriptMessageHandler(
            ReplyProxy(self), contentWorld: .page, name: "macarchy")
        webView.navigationDelegate = self
        webView.allowsMagnification = false
        webView.allowsBackForwardNavigationGestures = false
        if transparent {
            // No public API makes a WKWebView transparent on macOS; this key is
            // the long-standing way, and without it the panel's material
            // would sit behind an opaque white page.
            webView.setValue(false, forKey: "drawsBackground")
        }
        webView.underPageBackgroundColor = .clear
        #if DEBUG
        webView.isInspectable = true
        #endif

        router.register("app.ready") { [weak self] (_: ReadyParams) in
            self?.markReady()
            return Null()
        }
    }

    func load() {
        loaded = false
        isReady = false
        webView.load(URLRequest(url: Self.pageURL(surface)))
    }

    /// Development builds load the Vite server when `MACARCHY_UI_DEV_SERVER`
    /// names one on this machine, for hot reload. Release builds always use
    /// the bundled files.
    static func pageURL(_ surface: Surface) -> URL {
        #if DEBUG
        if let server = devServer {
            return server.appending(path: "\(surface.rawValue).html")
        }
        #endif
        return AppScheme.pageURL(surface)
    }

    static var devServer: URL? {
        #if DEBUG
        guard let value = ProcessInfo.processInfo.environment["MACARCHY_UI_DEV_SERVER"],
            let url = URL(string: value), ["localhost", "127.0.0.1"].contains(url.host())
        else { return nil }
        return url
        #else
        return nil
        #endif
    }

    private func markReady() {
        guard !isReady else { return }
        isReady = true
        readyWaiters.forEach { $0.resume() }
        readyWaiters = []
        onReady?()
    }

    /// Returns once the page is ready, or after `timeout` so a page that
    /// failed to load cannot keep its window hidden for good.
    func waitUntilReady(timeout: Duration) async {
        guard !isReady else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let once = Once(continuation)
            readyWaiters.append(once)
            Task { @MainActor in
                try? await Task.sleep(for: timeout)
                once.resume()
            }
        }
    }

    // MARK: - Events

    /// Delivers an event without waiting for the page to handle it.
    func send(_ event: BridgeEvent) {
        guard let json = Self.encode(event) else { return }
        guard loaded else {
            // A page that never loads must not collect events forever; it
            // fetches current state itself when it does.
            if pending.count < 32 { pending.append(json) }
            return
        }
        webView.callAsyncJavaScript(
            "window.macarchyBridge.receive(event)", arguments: ["event": json], in: nil,
            in: .page
        ) { [log] result in
            if case .failure(let error) = result {
                log.error("event not delivered: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Delivers an event and waits until the page has rendered it, or until
    /// `timeout`, whichever comes first. A page that never answers must not
    /// stop the panel from opening.
    func deliver(_ event: BridgeEvent, timeout: Duration = .milliseconds(300)) async {
        guard loaded, let json = Self.encode(event) else {
            send(event)
            return
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let once = Once(continuation)
            webView.callAsyncJavaScript(
                "return await window.macarchyBridge.receive(event)", arguments: ["event": json],
                in: nil, in: .page
            ) { _ in once.resume() }
            Task { @MainActor in
                try? await Task.sleep(for: timeout)
                once.resume()
            }
        }
    }

    private static func encode(_ event: BridgeEvent) -> String? {
        (try? JSONEncoder().encode(event)).flatMap { String(bytes: $0, encoding: .utf8) }
    }

    private func flush() {
        let queued = pending
        pending = []
        for json in queued {
            webView.callAsyncJavaScript(
                "window.macarchyBridge.receive(event)", arguments: ["event": json], in: nil,
                in: .page, completionHandler: nil)
        }
    }

    fileprivate func handle(_ message: WKScriptMessage) async -> String {
        // Only the page this surface loaded may use its bridge.
        guard message.frameInfo.isMainFrame, Self.isOwnPage(message.frameInfo.request.url) else {
            return "{\"ok\":false,\"error\":{\"code\":\"unavailable\",\"message\":\"Not allowed\"}}"
        }
        return await router.handle(message.body)
    }

    static func isOwnPage(_ url: URL?) -> Bool {
        guard let url else { return false }
        if url.scheme == AppScheme.scheme, url.host() == "ui" { return true }
        if let server = devServer, url.scheme == server.scheme, url.host() == server.host(),
            url.port == server.port
        {
            return true
        }
        return false
    }
}

extension WebSurface: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
        decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
    ) {
        if Self.isOwnPage(action.request.url) || action.request.url?.scheme == "about" {
            return decisionHandler(.allow)
        }
        // Links leave the app for the browser; nothing else may navigate away.
        if action.navigationType == .linkActivated, let url = action.request.url,
            ["http", "https", "mailto"].contains(url.scheme)
        {
            NSWorkspace.shared.open(url)
        }
        decisionHandler(.cancel)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
        loaded = true
        flush()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation?, withError error: Error) {
        log.error("page failed: \(error.localizedDescription, privacy: .public)")
    }

    func webView(
        _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation?,
        withError error: Error
    ) {
        log.error("page did not load: \(error.localizedDescription, privacy: .public)")
    }

    /// WebKit can end a page's process under memory pressure. The page holds
    /// no state worth keeping that the host cannot send again, so start over.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        log.error("web content process ended; reloading \(self.surface.rawValue, privacy: .public)")
        load()
    }
}

/// The user content controller keeps its handlers strongly; this keeps the
/// surface out of that cycle.
private final class ReplyProxy: NSObject, WKScriptMessageHandlerWithReply {
    weak var surface: WebSurface?

    init(_ surface: WebSurface) { self.surface = surface }

    func userContentController(
        _ userContentController: WKUserContentController, didReceive message: WKScriptMessage,
        replyHandler: @escaping @MainActor @Sendable (Any?, String?) -> Void
    ) {
        guard let surface else { return replyHandler(nil, "The window has closed.") }
        Task { @MainActor in
            replyHandler(await surface.handle(message), nil)
        }
    }
}

/// Resumes a continuation at most once, from whichever caller gets there first.
@MainActor
private final class Once {
    private var continuation: CheckedContinuation<Void, Never>?

    init(_ continuation: CheckedContinuation<Void, Never>) { self.continuation = continuation }

    func resume() {
        continuation?.resume()
        continuation = nil
    }
}
