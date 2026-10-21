import Foundation
import Testing

@testable import Macarchy

struct NeovimColourschemesTests {
    @Test("lists schemes from the config, lazy.nvim plugins and packs, once each")
    func discovery() throws {
        let home = FileManager.default.temporaryDirectory.appending(path: "nvim-\(UUID())")
        defer { try? FileManager.default.removeItem(at: home) }
        let files = [
            ".config/nvim/colors/mine.lua",
            ".local/share/nvim/lazy/tokyonight.nvim/colors/tokyonight-night.lua",
            ".local/share/nvim/lazy/tokyonight.nvim/colors/tokyonight-day.vim",
            ".local/share/nvim/lazy/other/colors/README.md",
            ".local/share/nvim/site/pack/themes/start/gruvbox/colors/gruvbox.vim",
            ".local/share/nvim/site/pack/themes/opt/gruvbox/colors/gruvbox.lua"
        ]
        for file in files {
            let url = home.appending(path: file)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data().write(to: url)
        }
        let names = NeovimColourschemes.discover(home: home, env: [:], runtimes: [])
        #expect(names == ["gruvbox", "mine", "tokyonight-day", "tokyonight-night"])
    }

    @Test("names that could escape a path or a command are rejected")
    func validation() {
        #expect(NeovimColourschemes.isValidName("rose-pine.dawn_2"))
        #expect(!NeovimColourschemes.isValidName("../x"))
        #expect(!NeovimColourschemes.isValidName("a b"))
        #expect(!NeovimColourschemes.isValidName("x;rm"))
        var theme = Theme(name: "t")
        theme.apps.nvimColorscheme = "bad name"
        #expect(throws: ConfigurationError.self) { try theme.validate() }
    }
}
