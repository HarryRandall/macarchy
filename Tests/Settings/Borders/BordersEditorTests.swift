import Desktop
import Testing
@testable import Settings

@MainActor
struct BordersEditorTests {
    @Test("manual edits and resets do not commit until Apply")
    func manualDraft() async throws {
        var writes: [BorderAppearance] = []
        let editor = BordersEditor { writes.append($0) }
        var original = BorderAppearance()
        original.width = 7
        original.radius = 0.3
        editor.load(original)
        editor.setLive(false)
        editor.draft.width = 6
        editor.draft.radius = nil
        editor.draft.activeColour = "0xff123456"
        editor.changed()
        try await Task.sleep(for: .milliseconds(250))
        #expect(writes.isEmpty)
        #expect(editor.applied == original)
        await editor.apply()
        #expect(writes == [editor.draft])
        #expect(!editor.hasChanges)
    }

    @Test("discard restores the whole draft without writing")
    func discard() {
        var writes = 0
        let editor = BordersEditor { _ in writes += 1 }
        editor.load(BorderAppearance())
        editor.setLive(false)
        editor.draft.visible = false
        editor.draft.inactiveColour = "0xffabcdef"
        editor.draft.excludedApps.append("Example")
        editor.changed()
        editor.discard()
        #expect(editor.draft == editor.applied)
        #expect(writes == 0)
    }

    @Test("switching to manual cancels queued live changes")
    func cancelQueuedLiveEdit() async throws {
        var writes = 0
        let editor = BordersEditor { _ in writes += 1 }
        editor.load(BorderAppearance())
        editor.draft.width = 9
        editor.changed()
        editor.setLive(false)
        try await Task.sleep(for: .milliseconds(250))
        #expect(writes == 0)
        #expect(editor.hasChanges)
        editor.setLive(true)
        #expect(!editor.live)
    }

    @Test("live edits are coalesced and commit the latest appearance")
    func liveEdits() async throws {
        var writes: [BorderAppearance] = []
        let editor = BordersEditor { writes.append($0) }
        editor.load(BorderAppearance())
        editor.draft.width = 9
        editor.changed()
        editor.draft.width = 10
        editor.changed()
        try await Task.sleep(for: .milliseconds(300))
        #expect(writes.count == 1)
        #expect(writes.first?.width == 10)
        #expect(!editor.hasChanges)
    }

    @Test("failed Apply preserves the draft and allows retry")
    func failedApply() async {
        var fails = true
        let editor = BordersEditor { _ in
            if fails { throw BorderApplyError(message: "Test failure") }
        }
        editor.load(BorderAppearance())
        editor.draft.width = 9
        await editor.apply()
        #expect(editor.applied.width == 6)
        #expect(editor.draft.width == 9)
        #expect(editor.error != nil)
        #expect(!editor.live)
        fails = false
        await editor.apply()
        #expect(!editor.hasChanges)
        #expect(editor.error == nil)
    }
}
