import Foundation
import Testing

@testable import Macarchy

/// Ghostty's own config belongs to the person. Macarchy only ever adds or
/// removes one include line, and both directions must leave everything else
/// exactly as it was.
@Suite("Ghostty include")
struct GhosttyConfigTests {
    @Test("adds the include once and keeps the rest of the file")
    func addsOnce() {
        let original = "font-size = 14\nbackground = #101010"
        let updated = GhosttyConfig.addingInclude(to: original)
        #expect(updated.hasPrefix(original + "\n"))
        #expect(GhosttyConfig.hasInclude(updated))
        #expect(GhosttyConfig.addingInclude(to: updated) == updated)
    }

    @Test("an empty or missing config gets just the include")
    func emptyConfig() {
        let updated = GhosttyConfig.addingInclude(to: "")
        #expect(updated == GhosttyConfig.comment + "\n" + GhosttyConfig.includeLine + "\n")
    }

    @Test("removing the include restores the original text")
    func removeRoundTrips() {
        let original = "font-size = 14\n"
        let added = GhosttyConfig.addingInclude(to: original)
        #expect(GhosttyConfig.removingInclude(from: added).hasPrefix("font-size = 14\n"))
        #expect(!GhosttyConfig.hasInclude(GhosttyConfig.removingInclude(from: added)))
    }

    @Test("other config-file lines are left alone")
    func unrelatedIncludes() {
        let text = "config-file = ?~/.config/ghostty/extra\n"
        #expect(!GhosttyConfig.hasInclude(text))
        #expect(GhosttyConfig.removingInclude(from: text) == text)
    }

    @Test("only colour settings from a theme reach Ghostty")
    func coloursAreAllowlisted() {
        let palette = """
            background = #101010
            palette = 4=#1e90ff
            command = /bin/sh -c 'touch /tmp/owned'
            initial-command = evil
            foreground = not-a-colour
            config-file = /tmp/elsewhere
            window-padding-x = 8
            """
        let rendered = GhosttyConfig.colours(from: palette)
        #expect(rendered.contains("background = #101010"))
        #expect(rendered.contains("palette = 4=#1e90ff"))
        #expect(!rendered.contains("command"))
        #expect(!rendered.contains("config-file"))
        #expect(!rendered.contains("not-a-colour"))
        #expect(!rendered.contains("padding"))
    }
}
