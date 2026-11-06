import Foundation
import Testing

@testable import App
@testable import Macarchy

extension WebInterfaceTests {
    /// Neovim, the one setup extra, on the parent's isolated environment.
    @MainActor
    @Suite("Setup's Neovim extra")
    struct SetupNeovimTests {
        @Test("only a ticked Neovim adds the zsh PATH line to the plan and the files")
        func neovimIsOptIn() async throws {
            try await withHarness(tools: []) { harness in
                try await withSetupResources(harness) {
                    let zshenv = Paths.home.appending(path: ".zshenv")
                    let plain = Setup.Choices(all: .keep)
                    var neovim = plain
                    neovim.extras = [ToolInstaller.Package.neovim.id]
                    #expect(!Setup.plan(plain).contains { $0.path == zshenv })
                    #expect(
                        Setup.plan(neovim).contains { $0.path == zshenv && $0.action == .include })

                    _ = await harness.model.setupSession.run(plain, app: nil, applyToDesktop: false)
                    #expect(!FileManager.default.fileExists(atPath: zshenv.path))

                    let report = await harness.model.setupSession.run(
                        neovim, app: nil, applyToDesktop: false)
                    #expect(report.failure == nil)
                    let text = try String(contentsOf: zshenv, encoding: .utf8)
                    #expect(text.components(separatedBy: "\n").contains(NeovimSetup.pathLine))
                }
            }
        }

        @Test("setup offers Neovim as its one extra")
        func offersNeovim() {
            #expect(Setup.extras.map(\.id) == ["neovim"])
        }
    }
}
