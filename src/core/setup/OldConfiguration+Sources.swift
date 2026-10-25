import Foundation

/// The files that run or read something in the old places: Macarchy's own
/// configs, the person's shell and Neovim startup files, Ghostty's config,
/// LaunchAgents and widgets.
extension OldConfiguration {
    struct Source: Sendable {
        enum Syntax: Equatable, Sendable {
            /// skhd's file, whose commands are each a shell command.
            case shortcuts
            /// A script, checked with this shell's `-n` after rewriting.
            case shell(String)
            case lua
            case ghostty
            /// Read for references only, never changed.
            case plain
        }

        /// Which old paths cleanup may point elsewhere in it.
        enum Scope: Sendable {
            /// Every moved script and the old Macarchy folder.
            case all
            /// Only the old Macarchy folder, so the link there can go.
            case legacyRoot
            case none
        }

        /// The file to write, links resolved.
        let url: URL
        let text: String
        let syntax: Syntax
        let scope: Scope

        var comment: String? {
            switch syntax {
            case .shortcuts, .shell, .ghostty: "#"
            case .lua: "--"
            case .plain: nil
            }
        }
    }

    /// Sources other than the old folders' own files.
    static func liveSources() -> [Source] {
        var sources: [Source] = []
        let skhdrc = written(Paths.skhdrc)
        if let text = text(of: skhdrc) {
            let inside = homeRelative(skhdrc) != nil
            sources.append(
                Source(
                    url: skhdrc, text: text, syntax: inside ? .shortcuts : .plain,
                    scope: inside ? .all : .none))
        }
        for file in StartupConfiguration.all {
            guard let text = text(of: file.url) else { continue }
            sources.append(
                Source(url: file.url, text: text, syntax: .shell("/bin/bash"), scope: .all))
        }
        sources += shellStartupFiles()
        sources += neovimFiles()
        for url in GhosttyConfig.loadedFiles {
            let target = written(url)
            guard let text = text(of: target) else { continue }
            let inside = homeRelative(target) != nil
            sources.append(
                Source(
                    url: target, text: text, syntax: inside ? .ghostty : .plain,
                    scope: inside ? .legacyRoot : .none))
        }
        sources += agentSources()
        for file in textFiles(under: Paths.widgetsDirectory) {
            guard let text = text(of: file) else { continue }
            sources.append(Source(url: file, text: text, syntax: .plain, scope: .none))
        }
        return sources
    }

    /// The person's shell startup files, in the home and in `~/.config/zsh`,
    /// where `ZDOTDIR` usually points.
    static func shellStartupFiles() -> [Source] {
        let home = Paths.home
        let zsh = [".zshenv", ".zprofile", ".zshrc", ".zlogin", ".zlogout"]
        var candidates = (zsh + [".bashrc", ".bash_profile", ".profile"])
            .map { home.appending(path: $0) }
        let zdotdir = home.appending(path: ".config/zsh")
        candidates += zsh.map { zdotdir.appending(path: $0) }
        let extra = (try? FileManager.default.contentsOfDirectory(atPath: zdotdir.path)) ?? []
        candidates += extra.filter { $0.hasSuffix(".zsh") || $0.hasSuffix(".sh") }.sorted()
            .map { zdotdir.appending(path: $0) }
        var seen = Set<String>()
        return candidates.compactMap { url in
            let target = written(url)
            guard seen.insert(target.path).inserted, let text = text(of: target) else { return nil }
            let name = url.lastPathComponent
            let shell =
                name.hasPrefix(".z") || name.hasSuffix(".zsh") ? "/bin/zsh" : "/bin/bash"
            // A file outside the home cannot be archived by its path, so it is
            // read for references but never changed.
            let inside = homeRelative(target) != nil
            return Source(
                url: target, text: text, syntax: inside ? .shell(shell) : .plain,
                scope: inside ? .all : .none)
        }
    }

    /// Neovim's Lua and Vim script files. Lua paths are pointed at the new
    /// folder where a string holds nothing but the path; Vim script is only read.
    static func neovimFiles() -> [Source] {
        let folder = Paths.home.appending(path: ".config/nvim")
        return textFiles(under: folder).compactMap { file in
            guard let text = text(of: file) else { return nil }
            switch file.pathExtension {
            case "lua" where homeRelative(file) != nil:
                return Source(url: file, text: text, syntax: .lua, scope: .legacyRoot)
            case "lua", "vim": return Source(url: file, text: text, syntax: .plain, scope: .none)
            default: return nil
            }
        }
    }

    /// LaunchAgents other than Macarchy's own, which it rewrites itself.
    static func agentSources() -> [Source] {
        let folder = DaemonAgents.agents
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return names.filter { $0.hasSuffix(".plist") && !$0.hasPrefix(DaemonAgents.prefix) }
            .sorted()
            .compactMap { name in
                let url = folder.appending(path: name)
                guard let data = try? Data(contentsOf: url),
                    let plist = try? PropertyListSerialization.propertyList(from: data, format: nil)
                else { return nil }
                return Source(
                    url: url, text: strings(in: plist).joined(separator: "\n"), syntax: .plain,
                    scope: .none)
            }
    }

    private static func strings(in value: Any) -> [String] {
        switch value {
        case let text as String: [text]
        case let array as [Any]: array.flatMap(strings)
        case let dictionary as [String: Any]: dictionary.values.flatMap(strings)
        default: []
        }
    }
}
