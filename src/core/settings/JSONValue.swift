import Foundation

/// Any JSON value, kept as written. Lets a file carry keys this version does
/// not know, such as those a newer Macarchy added, through a rewrite.
public enum JSONValue: Codable, Sendable, Equatable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() {
            self = .null
        } else if let boolean = try? value.decode(Bool.self) {
            self = .bool(boolean)
        } else if let number = try? value.decode(Double.self) {
            self = .number(number)
        } else if let text = try? value.decode(String.self) {
            self = .string(text)
        } else if let array = try? value.decode([JSONValue].self) {
            self = .array(array)
        } else {
            self = .object(try value.decode([String: JSONValue].self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self {
        case .null: try value.encodeNil()
        case .bool(let boolean): try value.encode(boolean)
        case .number(let number): try value.encode(number)
        case .string(let text): try value.encode(text)
        case .array(let array): try value.encode(array)
        case .object(let object): try value.encode(object)
        }
    }
}

/// A key not known at compile time, for reading and writing extra keys.
struct AnyCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil
    init(_ string: String) { stringValue = string }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}
