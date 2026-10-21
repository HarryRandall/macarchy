import AppKit
import Foundation
import Testing

@testable import App
@testable import Macarchy

// Pictures of the React pages in known states, for reviewing the interface
// by eye. Runs only when `MACARCHY_UI_SNAPSHOTS` names a folder to write PNGs
// into, so CI and ordinary runs skip it:
//
//     MACARCHY_UI_SNAPSHOTS=/tmp/shots swift test --filter InterfaceSnapshotTests
//
// The same isolated setup as the other web view tests; the helpers are in
// `WebTestSupport+Snapshots.swift`.

/// Snapshots the settings page as `name`: the Layout page rendered with a
/// gap of `gap`, then `prepare` run against it.
@MainActor
private func shootSettings(
    _ name: String, in harness: Harness, appearance: NSAppearance.Name = .darkAqua,
    gap: Int = 8, _ prepare: (WebSurface) async throws -> Void = { _ in }
) async throws {
    let (window, surface) = try settingsShot(harness, appearance: appearance)
    try await waitForLayout(surface, gap: gap)
    try await prepare(surface)
    try await save(surface, name)
    withExtendedLifetime(window) {}
}

/// The same, in a fresh harness with default settings.
@MainActor
private func shootSettings(
    _ name: String, currentTheme: String = "lumon", appearance: NSAppearance.Name = .darkAqua,
    _ prepare: (WebSurface) async throws -> Void = { _ in }
) async throws {
    try await withHarness(currentTheme: currentTheme) { harness in
        try await shootSettings(name, in: harness, appearance: appearance, prepare)
    }
}

extension WebInterfaceTests {
    @MainActor
    @Suite(
        "Interface snapshots",
        .enabled(if: snapshotFolder != nil, "set MACARCHY_UI_SNAPSHOTS to a folder to write them"))
    struct InterfaceSnapshotTests {
        @Test("settings window states")
        func settings() async throws {
            for (appearance, suffix) in [(NSAppearance.Name.aqua, "light"), (.darkAqua, "dark")] {
                try await shootSettings("settings-layout-\(suffix)", appearance: appearance)
            }

            try await shootSettings("settings-layout-gaps") { surface in
                try await run(
                    surface,
                    """
                    const heading = [...document.querySelectorAll("main *")]
                      .find((element) => element.childElementCount === 0
                        && element.textContent.trim() === "Gaps");
                    // Only the page scrolls; scrollIntoView would also move
                    // the shell, whose overflow is hidden.
                    const main = document.querySelector("main");
                    main.scrollTop += heading.getBoundingClientRect().top - main.getBoundingClientRect().top - 24;
                    """)
            }

            try await withHarness { harness in
                await harness.desktop.reject("window_gap", message: "invalid value for window_gap")
                try await shootSettings("settings-layout-apply-error", in: harness) { surface in
                    try await run(surface, #"page.setValue(page.range("Window gap"), 25);"#)
                    try await waitFor(
                        surface, "the apply error",
                        #"return [...document.querySelectorAll("[role=alert]")].some((a) => a.innerText.includes("Could not apply that change"));"#
                    )
                    try await waitForLayout(surface, gap: 8)
                }
            }

            try await withHarness(settings: ["YABAI_WINDOW_GAP": "12"]) { harness in
                await harness.desktop.stop()
                try await shootSettings("settings-layout-yabai-unreachable", in: harness, gap: 12) {
                    surface in
                    try await waitFor(
                        surface, "the saved-layout notice",
                        #"return page.text().includes("Showing your saved layout");"#)
                }
            }

            try await shootSettings("settings-layout-stack") { surface in
                try await run(surface, stackSegment + #"stack.click();"#)
                try await waitFor(
                    surface, "Stack chosen",
                    stackSegment + #"return stack.getAttribute("aria-pressed") === "true" && page.disabled(page.toggle("Auto balance"));"#
                )
            }

            try await shootSettings("settings-layout-sidebar-rail") { surface in
                try await run(
                    surface, #"document.querySelector('[aria-label="Hide sidebar"]').click();"#)
                try await waitFor(
                    surface, "the sidebar collapsed",
                    #"return !!document.querySelector('[aria-label="Show sidebar"]');"#)
            }

            for theme in ["lumon", "awakening"] {
                try await shootSettings("settings-layout-accent-\(theme)", currentTheme: theme)
            }
        }

        @Test("switcher states")
        func switcher() async throws {
            try await withHarness { harness in
                let (window, surface) = try await switcherShot(harness)
                try await save(surface, "switcher-themes", backing: switcherBacking)

                try await run(surface, #"page.setValue(page.search(), "night");"#)
                try await waitFor(
                    surface, "a filtered list",
                    "return page.rows().length >= 1 && page.rows().length < 9;")
                try await save(surface, "switcher-search", backing: switcherBacking)

                try await run(surface, #"page.setValue(page.search(), "zzz");"#)
                try await waitFor(
                    surface, "the empty state",
                    #"return page.text().includes("No matching themes");"#)
                try await save(surface, "switcher-no-matches", backing: switcherBacking)

                try await run(surface, #"page.setValue(page.search(), "");"#)
                try await waitFor(surface, "the full list", "return page.rows().length === 9;")
                try await run(surface, #"page.key(page.search(), "k", { metaKey: true });"#)
                try await waitFor(
                    surface, "the actions menu",
                    #"return !!document.querySelector('[role=listbox][aria-label="Actions"]');"#)
                try await save(surface, "switcher-actions", backing: switcherBacking)
                withExtendedLifetime(window) {}
            }

            try await withHarness { harness in
                for (index, red) in [0.15, 0.55, 0.9].enumerated() {
                    try harness.addBackground(
                        theme: "lumon", name: "\(index + 1)-shot.png", red: red)
                }
                harness.model.themes.reload()
                let (window, surface) = try await switcherShot(harness)
                try await run(surface, #"page.key(page.search(), "b", { metaKey: true });"#)
                try await waitFor(
                    surface, "three loaded thumbnails",
                    """
                    const grid = document.querySelector('[role=listbox][aria-label="Backgrounds in Lumon"]');
                    const images = [...(grid?.querySelectorAll("img") ?? [])];
                    return images.length === 3 && images.every((img) => img.complete && img.naturalWidth > 0);
                    """)
                try await save(surface, "switcher-backgrounds", backing: switcherBacking)
                withExtendedLifetime(window) {}
            }
        }
    }
}

/// The Stack option of the Layout page's layout control.
private let stackSegment = """
    const stack = [...document.querySelectorAll('[data-slot=segmented-control][aria-label="Layout"] button')]
      .find((button) => button.textContent.trim() === "Stack");

    """
