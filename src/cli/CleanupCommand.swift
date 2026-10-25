import Darwin
import Foundation
import Macarchy

/// `macarchy cleanup`: the plan by default, `--apply` to carry it out and
/// `--restore <archive>` to put an archive back.
func cleanUp(_ options: CommandArguments, usage: String) async throws {
    let restoring = options.flags.contains("--restore")
    if restoring != (options.values.count == 1) {
        throw CommandArguments.Invalid(
            message: restoring
                ? "Missing argument: the archive to restore"
                : "Unexpected argument \(options.values.first ?? "")",
            usage: usage)
    }
    guard restoring || options.flags.contains("--apply") else {
        let plan = await OldConfiguration.plan()
        print(plan.text)
        if plan.refusal != nil { exit(1) }
        if plan.hasChanges { print("\nNothing was changed. Do it with: macarchy cleanup --apply") }
        return
    }
    let report =
        restoring
        ? await OldConfiguration.restore(options.values[0])
        : await OldConfiguration.apply()
    for line in report.lines { print(line) }
    for command in report.commands {
        print(command.ok ? "Restarted: \(command.command)" : "Not restarted: \(command.summary)")
    }
    if let failure = report.failure { throw ConfigurationError(failure) }
    if report.commands.contains(where: { !$0.ok }) { exit(1) }
}
