import Foundation
import Testing

@testable import App
@testable import Macarchy

/// A running SketchyBar with a CPU and a battery item on the right. Queries
/// answer from that; every other call succeeds and is only recorded.
private func runBar(_ desktop: FakeDesktop) async {
    await desktop.answer("sketchybar") { arguments in
        guard arguments.first == "--query" else { return .success() }
        switch arguments.last {
        case "bar":
            return .success(#"{"height":35,"position":"top","items":["cpu","battery"]}"#)
        case "cpu", "battery":
            let label = arguments.last == "cpu" ? "12%" : "84%"
            return .success(
                #"{"geometry":{"position":"right","drawing":"on"},"label":{"value":"\#(label)"},"#
                    + #""bounding_rects":{"display-1":{"origin":[100,0],"size":[40,35]}}}"#)
        default:
            return .failure("no such item")
        }
    }
}

/// The Menu Bar page has drawn its preview and zones.
@MainActor
private func waitForMenuBar(_ surface: WebSurface) async throws {
    try await waitFor(
        surface, "the Menu Bar page",
        """
        return !!document.querySelector('[role=group][aria-label="Menu bar preview"]')
          && !!document.querySelector('button[aria-label="Move Battery"]');
        """)
}

/// The page's Apply, which sits with its controls rather than in the top bar.
private let applyButton = """
    const apply = [...document.querySelectorAll("#page-content button")]
      .find((button) => button.textContent.trim() === "Apply");
    """

extension WebInterfaceTests {
    @MainActor
    @Suite("Menu Bar page")
    struct MenuBarPageTests {
        @Test("the page shows the running bar, with Apply waiting for a change")
        func drawnFromTheBar() async throws {
            try await withHarness(tools: ["yabai", "sketchybar"]) { harness in
                await runBar(harness.desktop)
                let (_, surface) = try harness.settingsPage(pane: .menuBar)
                try await waitForMenuBar(surface)
                try await waitFor(
                    surface, "the readings and a disabled Apply",
                    applyButton + """
                        return page.text().includes("84%") && !!apply && page.disabled(apply)
                          && !page.text().includes("Open the editor");
                        """)
            }
        }

        @Test("Apply moves an item on the bar and saves it for startup")
        func appliesAMove() async throws {
            try await withHarness(tools: ["yabai", "sketchybar"]) { harness in
                await runBar(harness.desktop)
                let (_, surface) = try harness.settingsPage(pane: .menuBar)
                try await waitForMenuBar(surface)

                try await run(
                    surface,
                    #"page.key(document.querySelector('button[aria-label="Move CPU"]'), "ArrowLeft");"#
                )
                try await waitFor(
                    surface, "the keyboard move announced",
                    """
                    return [...document.querySelectorAll("[aria-live=polite]")]
                      .some((region) => region.textContent === "CPU, Left zone, 1 of 1");
                    """)
                try await run(surface, applyButton + "apply.click();")

                try await waitFor(
                    surface, "the change applied", applyButton + "return page.disabled(apply);")
                let calls = await harness.desktop.calls(to: "sketchybar")
                // The centre zone is off, so the move skips it.
                #expect(calls.contains { $0.contains("--set") && $0.contains("position=left") })
                let saved = try harness.store.read().barConfiguration
                #expect(saved?.components.first { $0.id == "cpu" }?.side == "left")
            }
        }

        @Test("a stopped bar says so and nothing can apply")
        func stoppedBar() async throws {
            try await withHarness(tools: ["yabai", "sketchybar"]) { harness in
                await harness.desktop.answer("sketchybar") { _ in
                    .failure("sketchybar is not running.")
                }
                let (_, surface) = try harness.settingsPage(pane: .menuBar)
                try await waitFor(
                    surface, "the bar reported as not running",
                    applyButton + """
                        return page.text().includes("The bar is not running") && page.disabled(apply);
                        """)
            }
        }
    }
}
