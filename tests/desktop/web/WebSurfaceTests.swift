import Foundation
import Testing
import WebKit

@testable import App
@testable import Macarchy

extension WebInterfaceTests {
    /// What every page relies on: loading through the app scheme, the
    /// scheme's limits and state broadcast to both entry points.
    @MainActor
    @Suite("Web surfaces")
    struct WebSurfaceTests {
        @Test("the settings page loads its bundle through the app scheme")
        func settingsPageLoads() async throws {
            try await withHarness { harness in
                let (_, surface) = try harness.settingsPage()
                // Record load failures from the first byte, then load again so
                // the script is in place.
                surface.webView.configuration.userContentController.addUserScript(
                    WKUserScript(
                        source: """
                            window.__failures = [];
                            window.addEventListener("error", (event) => {
                              const target = event.target;
                              window.__failures.push(target && (target.src || target.href) || String(event.message));
                            }, true);
                            """, injectionTime: .atDocumentStart, forMainFrameOnly: true))
                surface.load()
                try await waitForLayout(surface, gap: 8)

                let report = try #require(
                    try await run(
                        surface,
                        """
                        const assets = [...document.querySelectorAll("script[src], link[rel=stylesheet], link[rel=modulepreload]")]
                          .map((element) => element.src || element.href);
                        const loaded = performance.getEntriesByType("resource")
                          .filter((entry) => ["script", "link", "css", "other"].includes(entry.initiatorType)
                            && /\\.(js|css)$/.test(entry.name))
                          .map((entry) => entry.name);
                        const statuses = performance.getEntriesByType("resource")
                          .filter((entry) => typeof entry.responseStatus === "number" && entry.responseStatus !== 200)
                          .map((entry) => `${entry.name} ${entry.responseStatus}`);
                        const rules = [...document.styleSheets].reduce((sum, sheet) => sum + sheet.cssRules.length, 0);
                        return JSON.stringify({ page: location.href, assets, loaded, statuses, rules,
                          failures: window.__failures ?? ["no recorder"] });
                        """) as? String)
                let parsed = try #require(
                    try JSONSerialization.jsonObject(with: Data(report.utf8)) as? [String: Any])
                let assets = parsed["assets"] as? [String] ?? []
                let loaded = parsed["loaded"] as? [String] ?? []

                #expect(parsed["page"] as? String == "macarchy-app://ui/settings.html")
                #expect(
                    assets.count >= 2, "expected the entry script and the stylesheet: \(assets)")
                for url in assets + loaded {
                    #expect(
                        url.hasPrefix("macarchy-app://ui/"),
                        "\(url) is not served by the app scheme")
                }
                #expect(
                    (parsed["failures"] as? [String])?.isEmpty == true, "load failures: \(report)")
                #expect(
                    (parsed["statuses"] as? [String])?.isEmpty == true,
                    "non-200 responses: \(report)")
                #expect((parsed["rules"] as? Int ?? 0) > 0, "the stylesheet did not apply")
            }
        }

        @Test("a theme changed on disk reaches both pages without touching yabai")
        func broadcastAcrossEntryPoints() async throws {
            try await withHarness { harness in
                let recorder = ThemeRecorder()
                let (window, settings) = try harness.settingsPage()
                let (switcher, switcherSurface) = try harness.switcherPage(recorder: recorder)
                let broadcast = StateBroadcast(
                    settings: { window.surface }, switcher: { switcher.surface })
                broadcast.start(harness.model)

                let accent =
                    #"return getComputedStyle(document.documentElement).getPropertyValue("--accent").trim()"#
                try await waitForLayout(settings, gap: 8)
                try await waitFor(settings, "the Lumon accent", "\(accent) === \"#f2fcff\";")
                try await waitFor(
                    switcherSurface, "Lumon active",
                    #"return page.activeRow()?.textContent.startsWith("Lumon");"#)

                // As `macarchy theme awakening` would, from another process.
                try SettingsStore(url: harness.store.url).update { $0.currentTheme = "awakening" }

                try await waitFor(
                    switcherSurface, "Awakening active",
                    #"return page.activeRow()?.textContent.startsWith("Awakening") && page.rows().filter((row) => row.textContent.includes("active")).length === 1;"#
                )
                try await waitFor(settings, "the Awakening accent", "\(accent) === \"#ffff00\";")
                #expect(await harness.desktop.writes.isEmpty)
                #expect(recorder.applied.isEmpty)
                withExtendedLifetime(broadcast) {}
            }
        }

        @Test("the app scheme refuses paths outside the interface and themes")
        func schemeRefusesTraversal() async throws {
            try await withHarness { harness in
                try harness.addBackground(theme: "lumon", name: "1-office.png", red: 0.1)
                let (_, surface) = try harness.settingsPage()
                try await waitForLayout(surface, gap: 8)

                // `fetch` is limited to the page's own origin by its content
                // security policy, so media URLs are tried as images, against a
                // thumbnail that does load.
                let report = try #require(
                    try await run(
                        surface,
                        """
                        const status = async (url) => {
                          try { return String((await fetch(url)).status); } catch { return "failed"; }
                        };
                        const image = (url) => new Promise((resolve) => {
                          const img = new Image();
                          img.onload = () => resolve(img.naturalWidth > 0 ? "loaded" : "empty");
                          img.onerror = () => resolve("failed");
                          img.src = url;
                        });
                        return JSON.stringify({
                          ownPage: await status("macarchy-app://ui/settings.html"),
                          uiDots: await status("macarchy-app://ui/../Package.swift"),
                          uiEncoded: await status("macarchy-app://ui/..%2F..%2F..%2F..%2FPackage.swift"),
                          uiEncodedDots: await status("macarchy-app://ui/%2E%2E/%2E%2E/%2E%2E/%2E%2E/Package.swift"),
                          mediaFetch: await status("macarchy-app://media/theme/lumon/../../settings.json"),
                          thumbnail: await image("macarchy-app://media/theme/lumon/backgrounds/1-office.png?max=200"),
                          mediaDots: await image("macarchy-app://media/theme/lumon/../../settings.json"),
                          mediaEncoded: await image("macarchy-app://media/theme/lumon/..%2F..%2Fsettings.json"),
                          mediaManifest: await image("macarchy-app://media/theme/lumon/theme.json"),
                        });
                        """) as? String)
                let results = try #require(
                    try JSONSerialization.jsonObject(with: Data(report.utf8)) as? [String: String])

                #expect(results["ownPage"] == "200", "fetch itself must work: \(report)")
                #expect(results["thumbnail"] == "loaded", "a real thumbnail must load: \(report)")
                for key in ["uiDots", "uiEncoded", "uiEncodedDots", "mediaFetch"] {
                    #expect(results[key] != "200", "\(key) was served: \(report)")
                }
                for key in ["mediaDots", "mediaEncoded", "mediaManifest"] {
                    #expect(results[key] == "failed", "\(key) was served: \(report)")
                }
            }
        }
    }
}
