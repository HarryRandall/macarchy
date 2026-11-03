import Foundation

extension Setup {
    /// Setup stopped before changing anything, for the reason given.
    public struct Refused: LocalizedError, Sendable {
        public let reason: String
        public var errorDescription: String? { reason }
    }

    /// A yabairc kept with `--keep` is carried into a bash script, so a file
    /// written for another interpreter, such as zsh, or one bash cannot
    /// parse would start a broken daemon. Setup stops
    /// before changing anything and says what to do instead.
    static func checkKeepable() async throws {
        // Only a config setup would carry over: one whose Macarchy copy has
        // not been generated yet.
        // The bar is always Macarchy's widgets, so a sketchybarrc is never kept.
        let candidates = [(StartupConfiguration.yabairc.url, yabaiSource)]
        for case (let target, let url?) in candidates where !isGenerated(target) {
            guard let text = adoptable(url) else { continue }
            let name = Paths.display(url)
            let advice =
                "Setup did not change anything. Convert it to bash, move it aside, or set up "
                + "with --replace=yabai (Use Macarchy's defaults), which leaves it as it is."
            if let interpreter = foreignInterpreter(text) {
                throw Refused(
                    reason: "Your \(name) runs with \(interpreter), and keeping it only works for "
                        + "bash commands. \(advice)")
            }
            if let problem = await bashSyntaxProblem(text) {
                throw Refused(
                    reason:
                        "Your \(name) is not valid bash, so it cannot be kept: \(problem). \(advice)"
                )
            }
        }
    }

    /// The interpreter a kept file names in its `#!` line when that is not a
    /// shell bash can stand in for, such as `lua` for SbarLua or `zsh`.
    /// A file without a `#!` line is run by a shell and counts as bash.
    static func foreignInterpreter(_ text: String) -> String? {
        guard let first = text.split(separator: "\n", maxSplits: 1).first,
            first.hasPrefix("#!")
        else { return nil }
        let words = first.dropFirst(2).split(whereSeparator: \.isWhitespace).map(String.init)
        guard var program = words.first.map({ URL(fileURLWithPath: $0).lastPathComponent })
        else { return nil }
        if program == "env" {
            // `#!/usr/bin/env -S bash -e` names the program after its options.
            program =
                words.dropFirst().first { !$0.hasPrefix("-") && !$0.contains("=") }
                .map { URL(fileURLWithPath: $0).lastPathComponent } ?? program
        }
        return ["bash", "sh"].contains(program) ? nil : program
    }

    /// bash's own complaint about `text`, or nil when it parses.
    static func bashSyntaxProblem(_ text: String) async -> String? {
        await syntaxProblem(text, shell: "/bin/bash")
    }

    /// The same check with another shell's `-n`, such as zsh for a `.zshrc`.
    static func syntaxProblem(_ text: String, shell: String) async -> String? {
        let file = FileManager.default.temporaryDirectory.appending(
            path: "macarchy-keep-\(UUID()).sh")
        defer { try? FileManager.default.removeItem(at: file) }
        do { try text.write(to: file, atomically: true, encoding: .utf8) } catch {
            return error.localizedDescription
        }
        let result = await CommandRunner.run(shell, ["-n", file.path])
        guard !result.ok else { return nil }
        let message = result.stderr.split(separator: "\n").first.map(String.init) ?? "syntax error"
        // bash names the temporary file; the line number is what helps.
        return message.replacingOccurrences(of: file.path + ": ", with: "")
    }
}
