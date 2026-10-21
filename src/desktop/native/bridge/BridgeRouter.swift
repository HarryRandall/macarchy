import Foundation

/// A failure the page can act on, sent back in the reply envelope.
struct BridgeFailure: Error, Sendable {
    enum Code: String, Sendable {
        case unknownMethod = "unknown_method"
        case invalidParams = "invalid_params"
        case unavailable
        case operationFailed = "operation_failed"
        case `internal`
    }

    let code: Code
    let message: String

    init(_ code: Code, _ message: String) {
        self.code = code
        self.message = message
    }
}

/// Maps named requests to typed handlers for one surface.
///
/// Each surface registers only the methods it uses, so the switcher page
/// cannot reach Layout and neither can run anything the router does not name.
/// Handlers stay thin: they decode, call the shared operation, and encode.
@MainActor
final class BridgeRouter {
    private typealias Handler = @MainActor (Data) async throws -> Data
    typealias Types = (params: any Decodable.Type, result: any Encodable.Type)

    private var handlers: [String: Handler] = [:]
    private let encoder = JSONEncoder()
    /// The types each method decodes and encodes, so the contract tests can
    /// hold them to the fixtures the TypeScript contract writes.
    private(set) var contract: [String: Types] = [:]

    func register<Params: Decodable, Result: Encodable>(
        _ method: String, _ handler: @escaping @MainActor (Params) async throws -> Result
    ) {
        contract[method] = (Params.self, Result.self)
        let encoder = encoder
        handlers[method] = { data in
            let params: Params
            do { params = try JSONDecoder().decode(Params.self, from: data) } catch {
                throw BridgeFailure(.invalidParams, "\(method): \(Self.describe(error))")
            }
            return try encoder.encode(try await handler(params))
        }
    }

    /// Takes the message body WebKit delivers and returns the JSON reply.
    func handle(_ body: Any) async -> String {
        do {
            let (method, params) = try Self.unpack(body)
            guard let handler = handlers[method] else {
                throw BridgeFailure(.unknownMethod, "No bridge method named \(method).")
            }
            let value = try await handler(params)
            return "{\"ok\":true,\"value\":" + (String(bytes: value, encoding: .utf8) ?? "null")
                + "}"
        } catch let failure as BridgeFailure {
            return Self.errorReply(failure)
        } catch {
            return Self.errorReply(BridgeFailure(.internal, error.localizedDescription))
        }
    }

    private static func unpack(_ body: Any) throws -> (String, Data) {
        let object: Any
        if let text = body as? String {
            object = try JSONSerialization.jsonObject(with: Data(text.utf8))
        } else {
            object = body
        }
        guard let message = object as? [String: Any], let method = message["method"] as? String
        else { throw BridgeFailure(.invalidParams, "A bridge message needs a method name.") }
        let params = message["params"] ?? [String: Any]()
        guard JSONSerialization.isValidJSONObject(params) else {
            throw BridgeFailure(.invalidParams, "\(method): parameters must be an object.")
        }
        return (method, try JSONSerialization.data(withJSONObject: params))
    }

    private static func errorReply(_ failure: BridgeFailure) -> String {
        let error: [String: Any] = ["code": failure.code.rawValue, "message": failure.message]
        let data =
            (try? JSONSerialization.data(withJSONObject: ["ok": false, "error": error])) ?? Data()
        return String(bytes: data, encoding: .utf8)
            ?? #"{"ok":false,"error":{"code":"internal","message":"The reply could not be encoded."}}"#
    }

    private static func describe(_ error: Error) -> String {
        guard let decoding = error as? DecodingError else { return error.localizedDescription }
        switch decoding {
        case .keyNotFound(let key, _): return "missing \(key.stringValue)"
        case .typeMismatch(_, let context), .valueNotFound(_, let context),
            .dataCorrupted(let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return path.isEmpty ? context.debugDescription : "invalid \(path)"
        @unknown default: return error.localizedDescription
        }
    }
}
