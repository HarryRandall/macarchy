import Testing

@testable import Macarchy

@Suite("JSON locator")
struct JSONLocatorTests {
    private let text = """
        {
          "id": "clock",
          "settings": {
            "b": { "type": "toggle" },
            "a": { "type": "text" }
          },
          "rows": [
            { "label": "say \\"hi\\"\\n" },
            {
              "label": "two"
            }
          ]
        }
        """

    @Test("finds the line of every value, nested ones and list items included")
    func lines() {
        let locator = JSONLocator(text)
        #expect(locator.syntaxError == nil)
        #expect(locator.line(for: ["id"]) == 2)
        #expect(locator.line(for: ["settings", "a", "type"]) == 5)
        #expect(locator.line(for: ["rows", "0", "label"]) == 8)
        #expect(locator.line(for: ["rows", "1", "label"]) == 10)
    }

    @Test("falls back to the nearest parent for a path the document does not have")
    func parent() {
        #expect(JSONLocator(text).line(for: ["settings", "b", "missing"]) == 4)
    }

    @Test("keeps each object's keys in the order they were written")
    func order() {
        #expect(JSONLocator(text).keys(at: ["settings"]) == ["b", "a"])
    }

    @Test(
        "reports the line of the first syntax error",
        arguments: [
            ("{\n  \"a\": 1,\n}", 3, "Remove the comma before }"),
            ("{\n  \"a\": \"open\n}", 2, "Text in quotes cannot run onto the next line; use \\n"),
            ("{\n  \"a\" 1\n}", 2, "Expected : after \"a\""),
            ("{\n  \"a\": tru\n}", 2, "Expected true"),
            ("{\"a\": 1} {", 1, "Unexpected text after the end of the document")
        ])
    func syntax(text: String, line: Int, message: String) {
        #expect(JSONLocator(text).syntaxError == .init(line: line, message: message))
    }
}
