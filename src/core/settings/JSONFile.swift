import Foundation

/// Reads Macarchy's hand-editable JSON files with errors a person can act on.
///
/// Foundation's own messages ("The data couldn't be read because it is
/// missing.") name neither the file nor the key, so each decoding error is
/// rewritten as the file, the key path and what was expected there.
enum JSONFile {
    static func decode<Value: Decodable>(_ type: Value.Type, from url: URL) throws -> Value {
        let file = Paths.display(url)
        let data: Data
        do { data = try Data(contentsOf: url) } catch {
            throw ConfigurationError(ReadFailure.describe(error, at: url))
        }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch let error as DecodingError {
            throw ConfigurationError(describe(error, in: file))
        }
    }

    static func describe(_ error: DecodingError, in file: String) -> String {
        switch error {
        case .keyNotFound(let key, let context):
            return "\(file): \(path(context.codingPath + [key])) is missing."
        case .typeMismatch(let type, let context):
            return "\(file): \(path(context.codingPath)) should be \(describe(type))."
        case .valueNotFound(let type, let context):
            return "\(file): \(path(context.codingPath)) should be \(describe(type)), not null."
        case .dataCorrupted(let context):
            if context.codingPath.isEmpty {
                let reason =
                    (context.underlyingError as NSError?)?
                    .userInfo[NSDebugDescriptionErrorKey] as? String
                return "\(file) is not valid JSON"
                    + (reason.map { ": " + ReadFailure.sentence($0) } ?? ".")
            }
            return "\(file): \(path(context.codingPath)) is invalid: \(context.debugDescription)"
        @unknown default:
            return "\(file) could not be read: \(ReadFailure.sentence(error.localizedDescription))"
        }
    }

    /// `colors.borderActive` or `windowRules[2].app`.
    static func path(_ keys: [any CodingKey]) -> String {
        var text = ""
        for key in keys {
            if let index = key.intValue {
                text += "[\(index)]"
            } else {
                text += (text.isEmpty ? "" : ".") + key.stringValue
            }
        }
        return text.isEmpty ? "the top level" : text
    }

    private static func describe(_ type: Any.Type) -> String {
        switch type {
        case is SettingValue.Type: "a number, text, or true or false"
        case is Bool.Type: "true or false"
        case is Int.Type, is Double.Type: "a number"
        case is String.Type: "text"
        case is [Any].Type: "a list"
        default:
            String(describing: type).hasPrefix("Dictionary")
                || String(describing: type).hasPrefix("KeyedDecodingContainer")
                ? "an object" : "a \(String(describing: type))"
        }
    }
}
