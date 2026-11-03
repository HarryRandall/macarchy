import Foundation

/// One subcommand's arguments, checked before anything runs.
///
/// Every subcommand changes the desktop or its files, so an unknown flag, a
/// typo in a subcommand or `--help` must never fall through to the action.
struct CommandArguments {
    let flags: Set<String>
    let values: [String]
    /// Options given a value as `--name=value`, by name.
    let options: [String: String]

    /// A mistake in the arguments: printed with the subcommand's usage, exit 2.
    struct Invalid: Error {
        let message: String
        let usage: String
    }

    /// Asked for help: printed to standard output, exit 0, nothing run.
    struct Help: Error {
        let usage: String
    }

    /// Splits `arguments` into flags and values, refusing anything `usage`
    /// does not allow. `choices`, when given, lists the allowed first value.
    /// `options` names those that take a value as `--name=value`; a name in
    /// both `flags` and `options` may be given either way.
    init(
        _ arguments: [String], usage: String, flags allowed: Set<String> = [],
        options valued: Set<String> = [], values count: ClosedRange<Int> = 0...0,
        choices: [String]? = nil, conflicting: [Set<String>] = []
    ) throws {
        if arguments.contains(where: { $0 == "--help" || $0 == "-h" }) { throw Help(usage: usage) }
        var flags: Set<String> = []
        var values: [String] = []
        var options: [String: String] = [:]
        for argument in arguments {
            if argument.hasPrefix("-"), let equals = argument.firstIndex(of: "=") {
                let name = String(argument[..<equals])
                guard valued.contains(name) else {
                    throw Invalid(message: "Unknown option \(argument)", usage: usage)
                }
                guard options[name] == nil else {
                    throw Invalid(message: "\(name) is given twice", usage: usage)
                }
                options[name] = String(argument[argument.index(after: equals)...])
            } else if argument.hasPrefix("-") {
                guard allowed.contains(argument) else {
                    throw Invalid(message: "Unknown option \(argument)", usage: usage)
                }
                flags.insert(argument)
            } else {
                values.append(argument)
            }
        }
        for pair in conflicting where pair.isSubset(of: flags) {
            throw Invalid(
                message: "Choose one of \(pair.sorted().joined(separator: " and "))", usage: usage)
        }
        guard count.contains(values.count) else {
            let message =
                values.count > count.upperBound
                ? "Unexpected argument \(values[count.upperBound])" : "Missing argument"
            throw Invalid(message: message, usage: usage)
        }
        if let choices, let first = values.first, !choices.contains(first) {
            throw Invalid(message: "Unknown argument \(first)", usage: usage)
        }
        self.flags = flags
        self.values = values
        self.options = options
    }

    /// Exactly one value taken as written, for names the bar passes, such as
    /// a widget instance, which may begin with a hyphen. A name that is not
    /// found is refused by the command itself, so nothing here can act.
    static func literal(_ arguments: [String], usage: String) throws -> String {
        guard arguments.count == 1 else {
            throw Invalid(
                message: arguments.isEmpty
                    ? "Missing argument" : "Unexpected argument \(arguments[1])",
                usage: usage)
        }
        return arguments[0]
    }
}
