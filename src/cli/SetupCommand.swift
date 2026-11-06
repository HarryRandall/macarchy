import Darwin
import Foundation
import Macarchy

/// `macarchy setup`: configures the chosen tools, installing missing ones
/// first with `--install`. Without options it sets up the tools chosen
/// before, or all four, keeping the person's own configs, so scripts and
/// `tools/install.sh` need no answers.
func setUp(_ options: CommandArguments, usage: String) async throws {
    let choices = try setupChoices(options, usage: usage)
    // The CLI lives inside the app bundle, so its bundle is the app to link.
    let app = Bundle.main.bundleURL.pathExtension == "app" ? Bundle.main.bundleURL : nil
    let applyToDesktop = !options.flags.contains("--no-apply")
    let report = await SetupSession().run(
        choices, app: app, applyToDesktop: applyToDesktop,
        install: options.flags.contains("--install")
    ) { step in
        guard case .homebrew(let progress) = step else { return }
        switch progress {
        case .started(let package): print("Installing \(package.name) with Homebrew…")
        case .output(_, let line): print("  " + line)
        case .finished, .failed: break
        }
    }
    // Failed commands are already among the lines, worded as the app shows them.
    for line in report.lines where !line.isEmpty { print(line) }
    if let failure = report.failure { throw ConfigurationError(failure) }
    let missing = choices.tools.filter { !Paths.isInstalled($0.executableName) }
    if report.commands.contains(where: { !$0.ok }) {
        throw ConfigurationError(
            "The files are set up, but not everything was installed or started. "
                + "Check with: macarchy doctor")
    }
    if !missing.isEmpty {
        let names = Daemon.allCases.filter(missing.contains).map(\.displayName)
        print(
            "Not installed, so not started: \(names.joined(separator: ", ")). "
                + "Install with: macarchy setup --install")
    }
    print(
        applyToDesktop
            ? "Done. Check everything with: macarchy doctor"
            : "Files are set up. Start the services with: macarchy services")
}

/// The tools and per-tool starting points `setup`'s options ask for.
func setupChoices(_ options: CommandArguments, usage: String) throws -> Setup.Choices {
    func tools(_ option: String) throws -> [Daemon]? {
        guard let list = options.options[option] else { return nil }
        let names = list.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespaces).lowercased()
        }
        guard !names.isEmpty else {
            throw CommandArguments.Invalid(
                message: "\(option) needs at least one tool", usage: usage)
        }
        return try names.map { name in
            guard let daemon = Daemon(rawValue: name) else {
                throw CommandArguments.Invalid(
                    message: "Unknown tool \(name) in \(option); choose from "
                        + Daemon.allCases.map(\.rawValue).joined(separator: ", "),
                    usage: usage)
            }
            return daemon
        }
    }
    let chosen = try tools("--tools").map(Set.init) ?? Setup.chosenTools
    let keep = try tools("--keep") ?? []
    let replace = try tools("--replace") ?? []
    if let both = Daemon.allCases.first(where: { keep.contains($0) && replace.contains($0) }) {
        throw CommandArguments.Invalid(
            message: "\(both.rawValue) is given to both --keep and --replace", usage: usage)
    }
    var choices = Setup.Choices(
        tools: chosen, all: options.flags.contains("--replace") ? .replace : .keep)
    for daemon in keep { choices.existing[daemon] = .keep }
    for daemon in replace { choices.existing[daemon] = .replace }
    if options.flags.contains("--neovim") { choices.extras.insert(ToolInstaller.Package.neovim.id) }
    return choices
}

/// `macarchy uninstall`: puts the originals back and, with
/// `--remove-tools`, removes the tools Macarchy installed.
func uninstall(_ options: CommandArguments) async throws {
    let session = SetupSession()
    let removing = options.flags.contains("--remove-tools") ? session.installer.removable() : []
    let report = try await session.restoreOriginals(removing: removing) { step in
        guard case .homebrew(.started(let package)) = step else { return }
        print("Removing \(package.name) with Homebrew…")
    }
    for line in report.lines where !line.isEmpty { print(line) }
    if report.lines.allSatisfy(\.isEmpty) {
        print("Nothing to restore: setup has not changed any files.")
    }
    if !options.flags.contains("--remove-tools") {
        let installed = session.installer.removable().map(\.name)
        if !installed.isEmpty {
            print(
                "Macarchy installed \(installed.joined(separator: ", ")); remove "
                    + (installed.count == 1 ? "it" : "them") + " with: macarchy uninstall "
                    + "--remove-tools")
        }
    }
    if report.commands.contains(where: { !$0.ok }) { exit(1) }
}
