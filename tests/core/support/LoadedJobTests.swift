import Foundation
import Testing

@testable import Macarchy

/// The description is trimmed from a real `launchctl print` of a Macarchy
/// agent, keeping the nested blocks that sit around the parts that are read.
@Suite("Loaded launchd job")
struct LoadedJobTests {
    static let description = """
        gui/501/io.github.harryrandall.macarchy.yabai = {
        \tactive count = 1
        \tpath = /Users/alex/Library/LaunchAgents/io.github.harryrandall.macarchy.yabai.plist
        \ttype = LaunchAgent
        \tstate = running

        \tprogram = /opt/homebrew/bin/yabai
        \targuments = {
        \t\t/opt/homebrew/bin/yabai
        \t\t-c
        \t\t/Users/alex/Library/Application Support/Macarchy/config/yabairc
        \t}

        \tstdout path = /Users/alex/Library/Application Support/Macarchy/state/yabai.log
        \tstderr path = /Users/alex/Library/Application Support/Macarchy/state/yabai.log
        \tinherited environment = {
        \t\tPATH => /usr/bin:/bin
        \t\tSSH_AUTH_SOCK => /private/tmp/com.apple.launchd.x/Listeners
        \t}

        \tdefault environment = {
        \t\tPATH => /usr/bin:/bin:/usr/sbin:/sbin
        \t}

        \tenvironment = {
        \t\tPATH => /opt/homebrew/bin:/usr/bin:/bin
        \t\tXPC_SERVICE_NAME => io.github.harryrandall.macarchy.yabai
        \t}

        \tdomain = gui/501 [100005]
        \tendpoints = {
        \t\t"com.example.endpoint" = {
        \t\t\tport = 0x1234
        \t\t}
        \t}
        \tpid = 4242
        }
        """

    @Test("reads the arguments, the job's own environment and its log paths")
    func reads() {
        let job = LoadedJob(Self.description)
        let support = "/Users/alex/Library/Application Support/Macarchy"
        #expect(job.running)
        #expect(
            job.definition
                == LoadedJob.Definition(
                    arguments: ["/opt/homebrew/bin/yabai", "-c", "\(support)/config/yabairc"],
                    path: "/opt/homebrew/bin:/usr/bin:/bin",
                    standardOut: "\(support)/state/yabai.log",
                    standardError: "\(support)/state/yabai.log"))
    }

    /// A description that says nothing about the program must never read as
    /// matching an agent, or a stale job would be restarted as it is.
    @Test("a description without arguments has no definition")
    func missingArguments() {
        #expect(LoadedJob("state = running\npid = 42").definition == nil)
        #expect(LoadedJob("").definition == nil)
    }
}
