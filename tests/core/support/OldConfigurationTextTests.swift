import Foundation
import Testing

@testable import Macarchy

/// The text side of cleaning up: what names the old places, and pointing it
/// at the new ones. Homes are passed in, since the web view suites change
/// `MACARCHY_HOME` for the whole test process.
@Suite("Old configuration text")
struct OldConfigurationTextTests {
    typealias Reference = OldConfiguration.Reference

    @Test("references name an entry, a whole folder, or nothing")
    func references() {
        func found(_ text: String, comment: String? = "#") -> Set<Reference> {
            OldConfiguration.references(in: text, home: "/Users/a", comment: comment)
        }
        #expect(
            found("ctrl - return : /bin/bash \"$HOME/.config/yabai/launch_ghostty.sh\"")
                == [Reference(folder: "yabai", name: "launch_ghostty.sh")])
        #expect(
            found("x : ~/.config/skhd/run.sh; ${HOME}/.config/borders/b.sh")
                == [
                    Reference(folder: "skhd", name: "run.sh"),
                    Reference(folder: "borders", name: "b.sh")
                ])
        #expect(
            found("STATE=\"/Users/a/.config/yabai/float_state.json\"")
                == [Reference(folder: "yabai", name: "float_state.json")])
        #expect(found("cd ~/.config/yabai && ./x") == [Reference(folder: "yabai", name: nil)])
        #expect(
            found("source \"$HOME/.config/yabai/$NAME.sh\"") == [Reference(folder: "yabai", name: nil)])
        #expect(found("x \"$HOME/.config/yabai/lib/*.sh\"") == [Reference(folder: "yabai", name: "lib")])
        // Comments, other folders and paths that only start the same are not references.
        #expect(found("# Original config: ~/.config/skhd/skhdrc.backup").isEmpty)
        #expect(found("x : ~/.config/yabai-old/run.sh").isEmpty)
        #expect(found("x : /Users/b/.config/yabai/run.sh").isEmpty)
        #expect(found("x : /tmp/Users/a/.config/yabai/run.sh").isEmpty)
        #expect(found("-- ~/.config/yabai/x", comment: "--").isEmpty)
    }

    @Test("the old Macarchy folder is named unless only its launchers are")
    func legacyRoot() {
        func names(_ text: String) -> Bool {
            OldConfiguration.namesLegacyRoot(text, home: "/Users/a", comment: "#")
        }
        #expect(names("_ENV=\"$HOME/.config/macarchy/generated/shell-env\""))
        #expect(names("vim.fn.expand(\"~/.config/macarchy\")"))
        #expect(!names("yabai -c ~/.config/macarchy/macarchy-yabairc"))
        #expect(!names("# $HOME/.config/macarchy/generated/shell-env"))
        #expect(!names("$HOME/.config/macarchy-settings/themes"))
        #expect(names("$HOME/.config/macarchy/macarchy-yabairc.bak"))
    }

    @Test("moved scripts are pointed at in every spelling, quoted for the space")
    func mappings() {
        let mapping = OldPathScanner.Mapping(
            old: "/.config/yabai/launch.sh",
            new: "$HOME/Library/Application Support/Macarchy/scripts/launch.sh")
        func rewritten(_ text: String) -> (text: String, changed: Int) {
            LegacyLayout.rewritingOldPaths(text, home: "/Users/a", mappings: [mapping, .legacyRoot])
        }
        let new = "$HOME/Library/Application Support/Macarchy/scripts/launch.sh"
        #expect(rewritten("x : /bin/bash \"$HOME/.config/yabai/launch.sh\" 1").text == "x : /bin/bash \"\(new)\" 1")
        #expect(rewritten("x : ~/.config/yabai/launch.sh 1").text == "x : \"\(new)\" 1")
        #expect(rewritten("x : /Users/a/.config/yabai/launch.sh").text == "x : \"\(new)\"")
        #expect(
            rewritten("E=\"$HOME/.config/macarchy/generated/shell-env\"").text
                == "E=\"$HOME/Library/Application Support/Macarchy/generated/shell-env\"")
        for kept in [
            "x : '$HOME/.config/yabai/launch.sh'", "x : ~/.config/yabai/launch.sh.bak",
            "x : ~/.config/yabai/other.sh", "# ~/.config/yabai/launch.sh"
        ] {
            #expect(rewritten(kept) == (kept, 0))
        }
    }

    @Test("Lua strings that hold only a path are pointed at the new folder")
    func lua() {
        func rewritten(_ text: String) -> (text: String, changed: Int) {
            OldConfiguration.rewritingLua(text, home: "/Users/a")
        }
        #expect(
            rewritten("M.f = vim.fn.expand(\"~/.config/macarchy/generated/nvim-colorscheme\")")
                == ("M.f = vim.fn.expand(\"~/Library/Application Support/Macarchy/generated/nvim-colorscheme\")", 1))
        #expect(
            rewritten("local f = os.getenv('HOME') .. '/.config/macarchy/generated/x'")
                == ("local f = os.getenv('HOME') .. '/Library/Application Support/Macarchy/generated/x'", 1))
        #expect(
            rewritten("io.open(\"/Users/a/.config/macarchy\")")
                == ("io.open(\"/Users/a/Library/Application Support/Macarchy\")", 1))
        for kept in [
            "-- vim.fn.expand(\"~/.config/macarchy/x\")",
            "os.execute(\"sh ~/.config/macarchy/x\")",
            "local s = [[~/.config/macarchy/x]]",
            "local s = \"~/.config/macarchy/x y\"",
            "local s = \"~/.config/macarchy-old/x\""
        ] {
            #expect(rewritten(kept) == (kept, 0))
        }
    }

    @Test("Ghostty includes of the old folder are pointed at the new one")
    func ghostty() {
        let text = """
            font-size = 13
            config-file = ?/Users/a/.config/macarchy/generated/ghostty.conf
            config-file = "~/.config/macarchy/extra.conf"
            # config-file = ~/.config/macarchy/x
            config-file = ?/Users/a/Library/Application Support/Macarchy/generated/ghostty.conf
            """
        let rewritten = OldConfiguration.rewritingGhostty(text, home: "/Users/a")
        #expect(rewritten.changed == 2)
        #expect(
            rewritten.text == """
                font-size = 13
                config-file = ?/Users/a/Library/Application Support/Macarchy/generated/ghostty.conf
                config-file = "~/Library/Application Support/Macarchy/extra.conf"
                # config-file = ~/.config/macarchy/x
                config-file = ?/Users/a/Library/Application Support/Macarchy/generated/ghostty.conf
                """)
    }

    @Test("skhd text splits before each command and joins back as it was")
    func commands() {
        let text = """
            # Launch
            ctrl - return : /bin/bash "$HOME/.config/yabai/launch.sh"
            cmd - w -> [
                "Messages" : osascript -e 'quit'
                *          : "$HOME/.config/yabai/close.sh"
            ]
            .blacklist [ "x" ]
            """
        let parts = OldConfiguration.commands(in: text)
        #expect(parts.map { $0.prefix + $0.command }.joined(separator: "\n") == text)
        #expect(parts[1].command == " /bin/bash \"$HOME/.config/yabai/launch.sh\"")
        #expect(parts[0].command.isEmpty && parts.last?.command.isEmpty == true)
    }

    @Test("scripts are told apart by their #! line or name")
    func shells() {
        let url = URL(fileURLWithPath: "/tmp/x")
        #expect(OldConfiguration.shell(of: url, text: "#!/usr/bin/env bash\n") == "/bin/bash")
        #expect(OldConfiguration.shell(of: url, text: "#!/bin/sh\n") == "/bin/bash")
        #expect(OldConfiguration.shell(of: url, text: "#!/bin/zsh\n") == "/bin/zsh")
        #expect(OldConfiguration.shell(of: url, text: "#!/usr/bin/env python3\n") == nil)
        #expect(OldConfiguration.shell(of: url, text: "[]\n") == nil)
        #expect(
            OldConfiguration.shell(of: URL(fileURLWithPath: "/tmp/x.sh"), text: "echo") == "/bin/bash")
    }
}
