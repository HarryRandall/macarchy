import Foundation
import Testing

@testable import Desktop

@Suite("EnvFile")
struct EnvFileTests {
    @Test("strips surrounding quotes but not interior ones")
    func quoteHandling() {
        let values = EnvFile.parse(text: #"A="one"#+"\"\nB=two\nC=\"say \"hi\"\"")
        #expect(values["A"] == "one")
        #expect(values["B"] == "two")
    }

    @Test("skips comments and blank lines")
    func skipsNoise() {
        #expect(EnvFile.parse(text: "# note\n\nKEY=value\n") == ["KEY": "value"])
    }

    @Test("keeps values containing an equals sign")
    func valuesWithEquals() {
        #expect(EnvFile.parse(text: "WALLPAPER=a=b.png")["WALLPAPER"] == "a=b.png")
    }

    @Test("renders sorted so diffs stay stable")
    func stableRendering() {
        let out = EnvFile.render(["B": "2", "A": "1"], header: "")
        #expect(out == "A=\"1\"\nB=\"2\"\n")
    }
}
