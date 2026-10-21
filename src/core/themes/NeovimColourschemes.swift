import Foundation

/// Colourschemes Neovim can load on this Mac, found by reading folders.
///
/// Running `nvim --headless` would be more complete but executes the person's
/// whole config, which can install or update plugins, so discovery only lists
/// `colors/*.lua` and `colors/*.vim` in the places Neovim and lazy.nvim use.
public enum NeovimColourschemes {
    public static func discover(
        home: URL = Paths.home, env: [String: String] = ProcessInfo.processInfo.environment,
        runtimes: [URL]? = nil
    ) -> [String] {
        let app = env["NVIM_APPNAME"] ?? "nvim"
        let config =
            env["XDG_CONFIG_HOME"].map { URL(fileURLWithPath: $0) }
            ?? home.appending(path: ".config")
        let data =
            env["XDG_DATA_HOME"].map { URL(fileURLWithPath: $0) }
            ?? home.appending(path: ".local/share")
        var folders = [config.appending(path: "\(app)/colors")]
        folders += children(of: data.appending(path: "\(app)/lazy")).map {
            $0.appending(path: "colors")
        }
        for kind in ["start", "opt"] {
            for pack in children(of: data.appending(path: "\(app)/site/pack")) {
                folders += children(of: pack.appending(path: kind)).map {
                    $0.appending(path: "colors")
                }
            }
        }
        // Neovim's own schemes, such as habamax, ship in its runtime.
        folders +=
            runtimes
            ?? Paths.searchDirectories.map {
                URL(fileURLWithPath: $0).deletingLastPathComponent()
                    .appending(path: "share/nvim/runtime/colors")
            }
        var names = Set<String>()
        for folder in folders {
            for file in children(of: folder) where ["lua", "vim"].contains(file.pathExtension) {
                names.insert(file.deletingPathExtension().lastPathComponent)
            }
        }
        return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    public static func isValidName(_ name: String) -> Bool {
        name.range(of: "^[A-Za-z0-9][A-Za-z0-9_.-]*$", options: .regularExpression) != nil
    }

    private static func children(of folder: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
    }
}
