import Foundation

/// Where each value in a JSON document starts, so a problem can name its line.
///
/// `JSONDecoder` reports a coding path but no position, and Foundation's
/// parser gives neither in a form worth showing someone. This walks the text
/// once, records the line of every value by its path and the order each
/// object's keys were written in, and stops at the first syntax error.
struct JSONLocator {
    struct SyntaxError: Error, Equatable {
        let line: Int
        let message: String
    }

    private(set) var lines: [String: Int] = [:]
    private(set) var keyOrder: [String: [String]] = [:]
    private(set) var syntaxError: SyntaxError?

    private let bytes: [UInt8]
    private var index = 0
    private var line = 1

    init(_ text: String) {
        bytes = Array(text.utf8)
        do {
            skipWhitespace()
            try value(at: [])
            skipWhitespace()
            if index < bytes.count { throw fail("Unexpected text after the end of the document") }
        } catch let error as SyntaxError {
            syntaxError = error
        } catch {
            syntaxError = SyntaxError(line: line, message: error.localizedDescription)
        }
    }

    /// The line of the value at `path`, or of its nearest parent that has one.
    func line(for path: [String]) -> Int? {
        var path = path
        while true {
            if let found = lines[Self.key(path)] { return found }
            if path.isEmpty { return nil }
            path.removeLast()
        }
    }

    /// The keys of the object at `path`, in the order they were written.
    func keys(at path: [String]) -> [String] { keyOrder[Self.key(path)] ?? [] }

    private static func key(_ path: [String]) -> String { path.joined(separator: "\u{1F}") }

    private mutating func value(at path: [String]) throws {
        skipWhitespace()
        guard index < bytes.count else { throw fail("The document ends where a value should be") }
        lines[Self.key(path)] = line
        switch bytes[index] {
        case UInt8(ascii: "{"): try object(at: path)
        case UInt8(ascii: "["): try array(at: path)
        case UInt8(ascii: "\""): _ = try string()
        case UInt8(ascii: "t"): try literal("true")
        case UInt8(ascii: "f"): try literal("false")
        case UInt8(ascii: "n"): try literal("null")
        case UInt8(ascii: "-"), UInt8(ascii: "0")...UInt8(ascii: "9"): number()
        default:
            throw fail(
                "Expected a value such as text in quotes, a number, true, false, a list or an object"
            )
        }
    }

    private mutating func object(at path: [String]) throws {
        index += 1
        var keys: [String] = []
        skipWhitespace()
        if peek(UInt8(ascii: "}")) {
            index += 1
            keyOrder[Self.key(path)] = keys
            return
        }
        while true {
            skipWhitespace()
            guard peek(UInt8(ascii: "\"")) else { throw fail("Expected a key in double quotes") }
            let name = try string()
            skipWhitespace()
            guard peek(UInt8(ascii: ":")) else { throw fail("Expected : after \"\(name)\"") }
            index += 1
            keys.append(name)
            try value(at: path + [name])
            skipWhitespace()
            if peek(UInt8(ascii: ",")) {
                index += 1
                skipWhitespace()
                if peek(UInt8(ascii: "}")) { throw fail("Remove the comma before }") }
                continue
            }
            if peek(UInt8(ascii: "}")) {
                index += 1
                break
            }
            throw fail("Expected , or } after \"\(name)\"")
        }
        keyOrder[Self.key(path)] = keys
    }

    private mutating func array(at path: [String]) throws {
        index += 1
        skipWhitespace()
        if peek(UInt8(ascii: "]")) {
            index += 1
            return
        }
        var position = 0
        while true {
            try value(at: path + [String(position)])
            position += 1
            skipWhitespace()
            if peek(UInt8(ascii: ",")) {
                index += 1
                skipWhitespace()
                if peek(UInt8(ascii: "]")) { throw fail("Remove the comma before ]") }
                continue
            }
            if peek(UInt8(ascii: "]")) {
                index += 1
                return
            }
            throw fail("Expected , or ] in a list")
        }
    }

    private mutating func string() throws -> String {
        index += 1
        var scalars: [UInt8] = []
        while index < bytes.count {
            let byte = bytes[index]
            switch byte {
            case UInt8(ascii: "\""):
                index += 1
                return String(bytes: scalars, encoding: .utf8) ?? ""
            case UInt8(ascii: "\\"):
                guard index + 1 < bytes.count else {
                    throw fail("Text in quotes is missing its closing \"")
                }
                if bytes[index + 1] == UInt8(ascii: "u") {
                    index += 6
                } else {
                    scalars.append(bytes[index + 1])
                    index += 2
                }
            case UInt8(ascii: "\n"):
                throw fail("Text in quotes cannot run onto the next line; use \\n")
            default:
                scalars.append(byte)
                index += 1
            }
        }
        throw fail("Text in quotes is missing its closing \"")
    }

    private mutating func literal(_ word: String) throws {
        let expected = Array(word.utf8)
        guard index + expected.count <= bytes.count,
            Array(bytes[index..<index + expected.count]) == expected
        else { throw fail("Expected \(word)") }
        index += expected.count
    }

    private mutating func number() {
        let allowed = Set("+-.eE0123456789".utf8)
        while index < bytes.count, allowed.contains(bytes[index]) { index += 1 }
    }

    private mutating func skipWhitespace() {
        while index < bytes.count {
            switch bytes[index] {
            case UInt8(ascii: "\n"):
                line += 1
                index += 1
            case UInt8(ascii: " "), UInt8(ascii: "\t"), UInt8(ascii: "\r"):
                index += 1
            default:
                return
            }
        }
    }

    private func peek(_ byte: UInt8) -> Bool { index < bytes.count && bytes[index] == byte }

    private func fail(_ message: String) -> SyntaxError {
        SyntaxError(line: line, message: message)
    }
}
