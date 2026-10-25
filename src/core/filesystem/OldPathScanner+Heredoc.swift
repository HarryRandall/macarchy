import Foundation

extension OldPathScanner {
    /// A here-document waiting for its body, which starts on the next line.
    struct Heredoc: Equatable {
        var delimiter: [Unicode.Scalar]
        var stripsTabs: Bool
        /// The delimiter was quoted, even partly, so nothing in the body expands.
        var literal: Bool

        /// The here-document a `<<word` or `<<-word` at `index` opens, and
        /// where its word ends.
        static func parse(_ scalars: [Unicode.Scalar], at index: Int) -> (Heredoc, Int)? {
            var end = index + 2
            let strips = end < scalars.count && scalars[end] == "-"
            if strips { end += 1 }
            while end < scalars.count, scalars[end] == " " || scalars[end] == "\t" { end += 1 }
            var delimiter: [Unicode.Scalar] = []
            var literal = false
            var quote: Unicode.Scalar?
            while end < scalars.count {
                let character = scalars[end]
                if let open = quote {
                    if character == open { quote = nil } else { delimiter.append(character) }
                } else if character == "'" || character == "\"" {
                    quote = character
                    literal = true
                } else if character == "\\", end + 1 < scalars.count {
                    literal = true
                    end += 1
                    delimiter.append(scalars[end])
                } else if OldPathScanner.metacharacters.contains(character) {
                    break
                } else {
                    delimiter.append(character)
                }
                end += 1
            }
            guard !delimiter.isEmpty else { return nil }
            return (Heredoc(delimiter: delimiter, stripsTabs: strips, literal: literal), end)
        }

        /// The length of the line at `index`, with its line break, when it
        /// is the one that ends the here-document.
        func closingLine(in scalars: [Unicode.Scalar], at index: Int) -> Int? {
            var start = index
            if stripsTabs {
                while start < scalars.count, scalars[start] == "\t" { start += 1 }
            }
            var end = start
            while end < scalars.count, scalars[end] != "\n" { end += 1 }
            guard Array(scalars[start..<end]) == delimiter else { return nil }
            return min(end + 1, scalars.count) - index
        }
    }
}
