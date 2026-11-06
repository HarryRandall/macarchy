import Testing
@testable import Macarchy

@Suite("Source-preserving presentation")
struct BarPresentationTests {
    @Test("Stacked fixed reading widths compile identically for Apply and startup")
    func stackedReadingSlots() {
        var configuration = BarConfiguration()
        var component = BarComponent(id: "gpu", title: "GPU", side: "right", members: ["gpu.text"])
        component.presentation["gpu.text"] = [
            "align": "left", "width": "39", "icon.width": "36", "icon.align": "right",
            "icon.padding_left": "5", "icon.padding_right": "-5",
            "label.width": "29", "label.align": "right",
            "label.padding_left": "-25", "label.padding_right": "25"
        ]
        configuration.components = [component]
        let native = BarCommands.nativePresentation(component.presentation)["gpu.text"] ?? [:]
        #expect(native["icon.width"] == "0")
        #expect(native["label.width"] == "0")
        #expect(native["icon.padding_left"] == "41.0")
        #expect(native["label.padding_left"] == "40.0")
        #expect(native["width"] == "39")
        let apply = BarCommands.changes(configuration, from: BarConfiguration(), baseline: [:])
        let startup = BarCommands.settings(configuration, startup: true)
        for (key, value) in native {
            #expect(apply.contains(key + "=" + value))
            #expect(startup.contains(key + "=" + value))
        }
        #expect(component.presentation["gpu.text"]?["icon.width"] == "36")
        #expect(!apply.contains { $0.hasPrefix("script=") || $0.hasPrefix("label=") })
    }

    func configuration() -> BarConfiguration {
        var configuration = BarConfiguration()
        configuration.components = [
            BarComponent(
                id: "cpu", title: "CPU", side: "right",
                members: ["cpu.icon", "cpu.text", "gap.cpu"], brackets: ["cpu.bracket"])
        ]
        return configuration
    }

    @Test func noOpProducesNoArguments() {
        let value = configuration()
        #expect(BarCommands.changes(value, from: value, baseline: [:]).isEmpty)
    }

    @Test func oneNativePropertyDoesNotResetLayoutOrSources() {
        let old = configuration()
        var value = old
        value.components[0].presentation = ["cpu.text": ["label.font": "Menlo:Bold:12"]]
        #expect(
            BarCommands.changes(value, from: old, baseline: [:]) == [
                "--set", "cpu.text", "label.font=Menlo:Bold:12"
            ])
    }

    @Test func clearingRestoresCapturedOriginal() {
        var old = configuration()
        old.components[0].presentation = ["cpu.text": ["label.color": "0xff000000"]]
        old.components[0].presentationDefaults = ["cpu.text": ["label.color": "0xffffffff"]]
        var value = old
        value.components[0].presentation = [:]
        #expect(
            BarCommands.changes(value, from: old, baseline: [:]) == [
                "--set", "cpu.text", "label.color=0xffffffff"
            ])
    }

    @Test func unknownOriginalDoesNotInventAResetValue() {
        var old = configuration()
        old.components[0].presentation = ["cpu.text": ["label.color": "0xff000000"]]
        var value = old
        value.components[0].presentation = [:]
        #expect(BarCommands.changes(value, from: old, baseline: [:]).isEmpty)
    }

    @Test func replayPreservesNativeGapsAndBackgrounds() {
        let arguments = BarCommands.settings(configuration(), startup: true)
        #expect(!arguments.contains("width=0"))
        #expect(!arguments.contains("padding_left=2.0"))
        #expect(!arguments.contains("background.drawing=off"))
        #expect(!arguments.contains { $0.hasPrefix("script=") || $0.hasPrefix("update_freq=") })
    }

    @Test func presentationCannotReplaceSources() throws {
        var value = configuration()
        value.components[0].presentation = ["cpu.text": ["script": "something.sh"]]
        #expect(throws: ConfigurationError.self) { try value.validate() }
    }
}

extension BarPresentationTests {
    @Test func repeatedSpacingChangesUseCapturedNativePadding() {
        var old = configuration()
        old.components = [
            BarComponent(id: "calendar", title: "Clock", side: "right", members: ["calendar"])
        ]
        old.components[0].nativeTrailingPadding = 9
        old.componentSpacing = 4
        var value = old
        value.componentSpacing = 8
        let args = BarCommands.changes(
            value, from: old, baseline: ["calendar": ["padding_right": "13"]])
        #expect(args == ["--set", "calendar", "padding_right=8.0"])
        value.componentSpacing = 0
        #expect(BarCommands.changes(value, from: old, baseline: [:]).contains("padding_right=0.0"))
        value.componentSpacing = nil
        #expect(
            BarCommands.changes(value, from: old, baseline: [:]) == [
                "--set", "calendar", "padding_right=9.0"
            ])
    }
}
