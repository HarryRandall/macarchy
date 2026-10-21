import SwiftUI
import Testing

@testable import App

@Suite("Dialog lifecycle")
@MainActor
struct ModalRouterTests {
    @Test("Closing retains content until the fade finishes")
    func retainContentDuringExit() {
        let router = ModalRouter()
        router.present { Text("Dialog") }
        let presentation = router.presentationID
        router.dismiss()
        #expect(!router.isPresented)
        #expect(router.content != nil)
        router.finishDismissal(for: presentation)
        #expect(router.content == nil)
    }

    @Test("An older animation cannot clear a newer dialog")
    func reopeningDuringExit() {
        let router = ModalRouter()
        router.present { Text("First") }
        let first = router.presentationID
        router.dismiss()
        router.present { Text("Second") }
        router.finishDismissal(for: first)
        #expect(router.isPresented)
        #expect(router.content != nil)
        router.dismiss()
        router.finishDismissal(for: first)
        #expect(router.content != nil)
        router.finishDismissal(for: router.presentationID)
        #expect(router.content == nil)
    }
}
