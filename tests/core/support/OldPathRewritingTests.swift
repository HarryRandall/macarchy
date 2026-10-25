import Foundation
import Testing

@testable import Macarchy

@Suite("Pointing old paths at the new folder")
struct OldPathRewritingTests {
    @Test("old command paths are pointed at the new folder in every spelling")
    func rewritesPaths() {
        let new =
            "\"$HOME/Library/Application Support/Macarchy/Macarchy.app/Contents/MacOS/macarchy\""
        let old = "/.config/macarchy/Macarchy.app/Contents/MacOS/macarchy"
        func rewritten(_ text: String) -> String {
            LegacyLayout.rewritingOldPaths(text, home: "/Users/a").text
        }
        #expect(
            rewritten("ctrl - t : \"$HOME\(old)\" rules toggle") == "ctrl - t : \(new) rules toggle"
        )
        #expect(
            rewritten("ctrl - t : $HOME\(old) rules toggle") == "ctrl - t : \(new) rules toggle")
        #expect(rewritten("ctrl - t : ${HOME}\(old) theme next") == "ctrl - t : \(new) theme next")
        #expect(rewritten("ctrl - t : ~\(old); echo") == "ctrl - t : \(new); echo")
        #expect(rewritten("ctrl - t : /Users/a\(old)") == "ctrl - t : \(new)")
        #expect(
            rewritten("x : sh -c \"$HOME\(old) bar toggle\"")
                == "x : sh -c \"$HOME/Library/Application Support/Macarchy"
                + "/Macarchy.app/Contents/MacOS/macarchy bar toggle\"")
        #expect(
            rewritten("source $HOME/.config/macarchy/generated/x.sh")
                == "source \"$HOME/Library/Application Support/Macarchy/generated/x.sh\"")
    }

    @Test("comments, single quotes and other folders are left alone")
    func leavesOtherText() {
        func rewritten(_ text: String) -> (text: String, changed: Int) {
            LegacyLayout.rewritingOldPaths(text, home: "/Users/a")
        }
        for text in [
            "# Don't: $HOME/.config/macarchy/bin",
            "x : osascript -e 'do shell script \"$HOME/.config/macarchy/bin/a\"'",
            "x : $HOME/.config/macarchy-old/run",
            "x : \"~/.config/macarchy/run\"",
            "x : echo $HOME/x/.config/macarchy"
        ] {
            #expect(rewritten(text) == (text, 0))
        }
        let lines = "# it's mine\nctrl - t : $HOME/.config/macarchy/run"
        #expect(rewritten(lines).changed == 1)
    }

    @Test("a path already inside double quotes gets no quotes of its own")
    func rewritesInsideNestedQuotes() {
        let root = "$HOME/Library/Application Support/Macarchy"
        func rewritten(_ text: String) -> String {
            LegacyLayout.rewritingOldPaths(text, home: "/Users/a").text
        }
        #expect(
            rewritten("THEME=\"$(cat \"$HOME/.config/macarchy/generated/nvim\")\"")
                == "THEME=\"$(cat \"\(root)/generated/nvim\")\"")
        #expect(
            rewritten("THEME=\"`cat \"$HOME/.config/macarchy/generated/nvim\"`\"")
                == "THEME=\"`cat \"\(root)/generated/nvim\"`\"")
        #expect(
            rewritten("X=\"$(ls ~/.config/macarchy/themes)\"") == "X=\"$(ls \"\(root)/themes\")\"")
        #expect(rewritten("X=`cat ~/.config/macarchy/x`") == "X=`cat \"\(root)/x\"`")
        #expect(
            rewritten("x=\"$(case a in a) echo $HOME/.config/macarchy/x;; esac)\"")
                == "x=\"$(case a in a) echo \"\(root)/x\";; esac)\"")
        #expect(rewritten("echo \"a/Users/a/.config/macarchy\"").contains(".config/macarchy"))
    }

    @Test("a glob or brace after an unquoted path stays unquoted")
    func keepsExpansionsUnquoted() {
        let root = "$HOME/Library/Application Support/Macarchy"
        func rewritten(_ text: String) -> String {
            LegacyLayout.rewritingOldPaths(text, home: "/Users/a").text
        }
        #expect(
            rewritten("for f in ~/.config/macarchy/themes/*; do :; done")
                == "for f in \"\(root)/themes/\"*; do :; done")
        #expect(rewritten("cp $HOME/.config/macarchy/{a,b} .") == "cp \"\(root)/\"{a,b} .")
        #expect(rewritten("ls ~/.config/macarchy/$NAME") == "ls \"\(root)/\"$NAME")
        #expect(
            rewritten("echo ${X:-$HOME/.config/macarchy}") == "echo ${X:-$HOME/.config/macarchy}")
    }

    @Test("here-documents follow their delimiter's quoting")
    func rewritesHeredocs() {
        let root = "$HOME/Library/Application Support/Macarchy"
        func rewritten(_ text: String) -> (text: String, changed: Int) {
            LegacyLayout.rewritingOldPaths(text, home: "/Users/a")
        }
        let open = rewritten(
            "cat <<EOF\nit's $HOME/.config/macarchy/x\nEOF\necho ~/.config/macarchy/y")
        #expect(open.text == "cat <<EOF\nit's \(root)/x\nEOF\necho \"\(root)/y\"")
        #expect(open.changed == 2)
        let quoted = rewritten(
            "cat <<'EOF'\n$HOME/.config/macarchy/x\nEOF\necho ~/.config/macarchy/y")
        #expect(quoted.text == "cat <<'EOF'\n$HOME/.config/macarchy/x\nEOF\necho \"\(root)/y\"")
        let tabs = rewritten(
            "cat <<-\"E\"F >x\n\t$HOME/.config/macarchy\n\tEF\nls ~/.config/macarchy")
        #expect(tabs.text.hasPrefix("cat <<-\"E\"F >x\n\t$HOME/.config/macarchy\n\tEF\n"))
        #expect(tabs.changed == 1)
        #expect(
            rewritten("echo $((1<<2))\nls ~/.config/macarchy").text
                == "echo $((1<<2))\nls \"\(root)\"")
    }

    @Test("rewritten scripts run as the originals did against the new folder")
    func rewrittenScriptsRun() async throws {
        let home = FileManager.default.temporaryDirectory.appending(path: "macarchy-run-\(UUID())")
        defer { try? FileManager.default.removeItem(at: home) }
        let root = home.appending(path: "Library/Application Support/Macarchy")
        for name in ["generated/nvim", "themes/a/theme.json", "themes/b/theme.json"] {
            let file = root.appending(path: name)
            try FileManager.default.createDirectory(
                at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try "ok".write(to: file, atomically: true, encoding: .utf8)
        }
        let script = """
            THEME="$(cat "$HOME/.config/macarchy/generated/nvim")"
            echo "theme=$THEME"
            for f in ~/.config/macarchy/themes/*/theme.json; do echo "found $(cat "$f")"; done
            cat <<EOF
            it's $(cat $HOME/.config/macarchy/generated/nvim)
            EOF
            """
        let rewritten = await LegacyLayout.rewritingOldPaths(inScript: script, home: home.path)
        #expect(rewritten.changed == 3 && rewritten.unsafe == 0, "\(rewritten.text)")
        let result = await CommandRunner.run(
            "/bin/bash", ["-c", rewritten.text],
            environment: ["HOME": home.path, "PATH": "/bin:/usr/bin"])
        #expect(result.stdout == "theme=ok\nfound ok\nfound ok\nit's ok", "\(result.stderr)")
    }

    @Test("a rewrite that would not parse is left as written")
    func leavesUnparsableText() async {
        let broken = "echo \"$HOME/.config/macarchy/x\" )"
        let script = await LegacyLayout.rewritingOldPaths(inScript: broken, home: "/Users/a")
        #expect(script == LegacyLayout.Rewrite(text: broken, changed: 0, unsafe: 1))
        let shortcuts = """
            # $HOME/.config/macarchy
            ctrl - a : "$HOME/.config/macarchy/Macarchy.app/Contents/MacOS/macarchy" theme next
            ctrl - b : echo "$HOME/.config/macarchy/x" )
            cmd - w -> [
                "App: one" : ~/.config/macarchy/run \\
                    --flag
            ]
            """
        let rewritten = await LegacyLayout.rewritingOldPaths(
            inShortcuts: shortcuts, home: "/Users/a")
        #expect(rewritten.changed == 2 && rewritten.unsafe == 1)
        let lines = rewritten.text.components(separatedBy: "\n")
        #expect(lines[0] == "# $HOME/.config/macarchy")
        #expect(lines[1].hasPrefix("ctrl - a : \"$HOME/Library/Application Support/Macarchy/"))
        #expect(lines[2] == "ctrl - b : echo \"$HOME/.config/macarchy/x\" )")
        #expect(
            lines[4] == "    \"App: one\" : \"$HOME/Library/Application Support/Macarchy/run\" \\")
    }
}
