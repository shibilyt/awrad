import AwradTesting
import Foundation
import Testing

@testable import AwradData

// Drift protection for the hand-written wire types (root ADR-2026-10-16): every operation the app
// uses must exist in contracts/api/openapi.bundled.json as the app calls it, and every request and
// response example of it must decode into the app's type and re-encode to the same JSON.

@Suite("OpenAPI contract")
struct OpenAPIContractTests {
    /// The app's type for each operation's request body and success body (`nil`: none).
    static let wireTypes: [String: (request: WireType?, success: WireType?)] = [
        "register_account": (WireType(RegisterAccountBody.self), nil),
        "verify_account_email": (WireType(VerifyEmailBody.self), nil),
        "resend_verification_code": (WireType(EmailOnlyBody.self), nil),
        "request_password_reset": (WireType(EmailOnlyBody.self), nil),
        "reset_password": (WireType(ResetPasswordBody.self), nil),
        "get_current_account": (nil, WireType(AccountWire.self)),
        "create_device_session": (WireType(CreateDeviceSessionBody.self), WireType(DeviceSessionGrantWire.self)),
        "refresh_device_session": (WireType(RefreshTokenBody.self), WireType(DeviceSessionGrantWire.self)),
        "sign_out_device_session": (WireType(RefreshTokenBody.self), nil),
    ]

    @Test(arguments: APIOperation.used)
    func operationMatchesTheSpec(_ operation: APIOperation) throws {
        let spec = try Spec.load()
        let entry = try #require(
            spec.operation(operation.method.rawValue, operation.path), "\(operation) isn't in the spec")
        #expect(entry["operationId"] as? String == operation.id)

        let security = entry["security"] as? [[String: Any]] ?? []
        switch operation.credential {
        case .none: #expect(security.isEmpty, "\(operation) is public in the spec")
        case .bearer: #expect(security.contains { $0["bearerAuth"] != nil }, "\(operation) takes a bearer token")
        }

        let headers = try spec.headerParameters(of: entry)
        #expect((headers["Idempotency-Key"] != nil) == operation.sendsIdempotencyKey, "\(operation): Idempotency-Key")
        #expect((headers["Accept-Language"] != nil) == operation.sendsAcceptLanguage, "\(operation): Accept-Language")
        if operation == .refreshDeviceSession {
            #expect(headers["Idempotency-Key"] == true, "refresh requires the key")
        }
    }

    @Test(arguments: APIOperation.used)
    func everyExampleRoundTrips(_ operation: APIOperation) throws {
        let spec = try Spec.load()
        let entry = try #require(spec.operation(operation.method.rawValue, operation.path))
        let types = try #require(Self.wireTypes[operation.id], "\(operation) has no wire types")

        if let requestBody = entry["requestBody"] as? [String: Any] {
            let type = try #require(types.request, "\(operation) has a request body the app doesn't model")
            let examples = try spec.examples(in: spec.resolve(requestBody))
            #expect(!examples.isEmpty, "\(operation): request has no example")
            for example in examples { try expectRoundTrip(example, through: type, "\(operation) request") }
        } else {
            #expect(types.request == nil, "\(operation) has no request body in the spec")
        }

        let responses = try #require(entry["responses"] as? [String: Any])
        for (status, raw) in responses.sorted(by: { $0.key < $1.key }) {
            let response = try spec.resolve(try #require(raw as? [String: Any]))
            let isSuccess = status.hasPrefix("2")
            let examples = spec.examples(in: response)
            let hasContent = response["content"] != nil
            if isSuccess {
                #expect((types.success != nil) == hasContent, "\(operation) \(status): success body")
            }
            guard hasContent else { continue }
            #expect(!examples.isEmpty, "\(operation) \(status) has no example")
            let type = isSuccess ? types.success : WireType(ProblemWire.self)
            for example in examples {
                try expectRoundTrip(example, through: try #require(type), "\(operation) \(status)")
            }
        }
    }

    /// The mobile operations in the spec are exactly the ones the app implements.
    @Test func theAppCoversEveryMobileOperation() throws {
        let spec = try Spec.load()
        let mobile = spec.operationIDs(taggedAny: ["accounts", "device_sessions"])
        #expect(Set(APIOperation.used.map(\.id)) == mobile)
        #expect(Set(Self.wireTypes.keys) == mobile)
    }

    private func expectRoundTrip(_ example: Any, through type: WireType, _ label: String) throws {
        let original = try JSONSerialization.data(withJSONObject: example, options: [.fragmentsAllowed])
        let reencoded: Data
        do {
            reencoded = try type.roundTrip(original)
        } catch {
            Issue.record("\(label): example doesn't decode: \(error)")
            return
        }
        let decoder = JSONDecoder()
        #expect(
            try decoder.decode(JSONValue.self, from: original) == decoder.decode(JSONValue.self, from: reencoded),
            "\(label): re-encoded example differs")
    }
}

/// Decode-then-encode through one Codable type.
struct WireType: Sendable {
    let roundTrip: @Sendable (Data) throws -> Data

    init<Value: Codable & Sendable>(_: Value.Type) {
        roundTrip = { data in try JSONEncoder().encode(JSONDecoder().decode(Value.self, from: data)) }
    }
}

/// Any JSON value, for exact comparison (`true` never equals `1`).
enum JSONValue: Decodable, Equatable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }
}

/// `openapi.bundled.json`, read straight from the repository's contracts/api.
struct Spec {
    let root: [String: Any]

    static func load() throws -> Spec {
        let file = try FixtureLoader.contractsDirectory(holding: "api").appending(path: "api/openapi.bundled.json")
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: file))
        return Spec(root: try #require(object as? [String: Any]))
    }

    func operation(_ method: String, _ path: String) -> [String: Any]? {
        let item = (root["paths"] as? [String: Any])?[path] as? [String: Any]
        return item?[method.lowercased()] as? [String: Any]
    }

    func operationIDs(taggedAny tags: Set<String>) -> Set<String> {
        let paths = root["paths"] as? [String: [String: Any]] ?? [:]
        return Set(
            paths.values.flatMap(\.values).compactMap { raw -> String? in
                guard let operation = raw as? [String: Any], let id = operation["operationId"] as? String,
                    let operationTags = operation["tags"] as? [String], !tags.isDisjoint(with: operationTags)
                else { return nil }
                return id
            })
    }

    /// Header parameter names, each mapped to whether it's required.
    func headerParameters(of operation: [String: Any]) throws -> [String: Bool] {
        let parameters = try (operation["parameters"] as? [[String: Any]] ?? []).map(resolve)
        return Dictionary(
            parameters.filter { $0["in"] as? String == "header" }
                .compactMap { parameter in
                    (parameter["name"] as? String).map { ($0, parameter["required"] as? Bool ?? false) }
                },
            uniquingKeysWith: { first, _ in first })
    }

    /// Follows a local `$ref` (`#/components/...`).
    func resolve(_ object: [String: Any]) throws -> [String: Any] {
        guard let ref = object["$ref"] as? String else { return object }
        var node: Any = root
        for part in ref.dropFirst(2).split(separator: "/") {
            node = try #require((node as? [String: Any])?[String(part)], "unresolvable \(ref)")
        }
        return try resolve(try #require(node as? [String: Any]))
    }

    /// Every example of every media type in a request body or response.
    func examples(in object: [String: Any]) -> [Any] {
        let content = object["content"] as? [String: [String: Any]] ?? [:]
        return content.values.flatMap { media -> [Any] in
            if let example = media["example"] { return [example] }
            let named = media["examples"] as? [String: [String: Any]] ?? [:]
            return named.values.compactMap { $0["value"] }
        }
    }
}
