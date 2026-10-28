import Foundation

// The `awrad-fixture/1` runner (contracts/FIXTURES.md): loads a rule's fixture file straight from
// the repository's `contracts/` (never a copy) and decodes every case's `given` and `expect`.
// Tests hand `given` to the real domain code and compare the result with `expect`; a
// parameterized `@Test` names each run by the case ID.

/// One case of a fixture file, decoded. Its description is the case ID, so test reports name it.
public struct FixtureCase<Given: Sendable, Expect: Sendable>: Sendable, CustomStringConvertible {
    public let id: String
    public let summary: String
    public let given: Given
    public let expect: Expect

    public var description: String { id }
}

/// Why a fixture file couldn't be run. Every one of these fails the test that loads the file.
public enum FixtureError: Error, Equatable, CustomStringConvertible {
    case contractsNotFound(searchedFrom: String)
    case missingFile(String)
    case malformedFile(String, reason: String)
    case noCases(String)
    case undecodableCase(file: String, id: String, reason: String)

    public var description: String {
        switch self {
        case .contractsNotFound(let path): "No contracts/ directory above \(path)"
        case .missingFile(let path): "Fixture file missing: \(path)"
        case .malformedFile(let path, let reason): "Malformed fixture file \(path): \(reason)"
        case .noCases(let path): "Fixture file has no cases: \(path)"
        case .undecodableCase(let file, let id, let reason): "Case \(id) in \(file) can't be run: \(reason)"
        }
    }
}

public enum FixtureLoader {
    static let format = "awrad-fixture/1"

    /// The repository's `contracts/` directory: the nearest one above `filePath` that holds `model`.
    public static func contractsDirectory(holding model: String, from filePath: String = #filePath) throws -> URL {
        var directory = URL(filePath: filePath).deletingLastPathComponent()
        while directory.pathComponents.count > 1 {
            let contracts = directory.appending(path: "contracts", directoryHint: .isDirectory)
            if FileManager.default.fileExists(atPath: contracts.appending(path: model).path()) {
                return contracts
            }
            directory = directory.deletingLastPathComponent()
        }
        throw FixtureError.contractsNotFound(searchedFrom: filePath)
    }

    /// `contracts/<model>/v1/fixtures/` in this repository.
    public static func fixturesDirectory(model: String, from filePath: String = #filePath) throws -> URL {
        try contractsDirectory(holding: model, from: filePath).appending(path: "\(model)/v1/fixtures")
    }

    /// The rule names of every fixture file in `contracts/<model>/v1/fixtures/`, sorted. The
    /// runner checks each has a rule iOS implements, so a new file can't go unrun.
    public static func ruleFiles(model: String) throws -> [String] {
        let directory = try fixturesDirectory(model: model)
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }

    /// Loads `<rule>.json`, checks its format and rule name, and decodes every case.
    /// Fails when the file is missing, malformed, has no cases, or has a case that doesn't decode.
    /// `convertingSnakeCase: false` keeps every key as written, for fixtures whose values hold JSON
    /// documents (the decoder's key strategy would also rewrite their member names).
    public static func load<Given: Decodable & Sendable, Expect: Decodable & Sendable>(
        _ file: URL,
        rule: String,
        as _: (Given.Type, Expect.Type),
        convertingSnakeCase: Bool = true
    ) throws -> [FixtureCase<Given, Expect>] {
        let path = file.path()
        guard FileManager.default.fileExists(atPath: path) else { throw FixtureError.missingFile(path) }
        let root: [String: Any]
        do {
            let object = try JSONSerialization.jsonObject(with: Data(contentsOf: file))
            guard let dictionary = object as? [String: Any] else {
                throw FixtureError.malformedFile(path, reason: "not a JSON object")
            }
            root = dictionary
        } catch let error as FixtureError {
            throw error
        } catch {
            throw FixtureError.malformedFile(path, reason: error.localizedDescription)
        }
        guard root["format"] as? String == format else {
            throw FixtureError.malformedFile(path, reason: "format isn't \(format)")
        }
        guard root["rule"] as? String == rule else {
            throw FixtureError.malformedFile(path, reason: "rule isn't \(rule)")
        }
        guard let cases = root["cases"] as? [[String: Any]] else {
            throw FixtureError.malformedFile(path, reason: "cases isn't an array of objects")
        }
        guard !cases.isEmpty else { throw FixtureError.noCases(path) }
        return try cases.map { try decodeCase($0, file: path, convertingSnakeCase: convertingSnakeCase) }
    }

    private static func decodeCase<Given: Decodable & Sendable, Expect: Decodable & Sendable>(
        _ raw: [String: Any],
        file: String,
        convertingSnakeCase: Bool
    ) throws -> FixtureCase<Given, Expect> {
        guard let id = raw["id"] as? String else {
            throw FixtureError.malformedFile(file, reason: "a case has no id")
        }
        do {
            guard let given = raw["given"], let expect = raw["expect"] else {
                throw FixtureError.undecodableCase(file: file, id: id, reason: "given or expect missing")
            }
            return FixtureCase(
                id: id,
                summary: raw["description"] as? String ?? "",
                given: try decode(Given.self, from: given, convertingSnakeCase: convertingSnakeCase),
                expect: try decode(Expect.self, from: expect, convertingSnakeCase: convertingSnakeCase)
            )
        } catch let error as FixtureError {
            throw error
        } catch {
            throw FixtureError.undecodableCase(file: file, id: id, reason: String(describing: error))
        }
    }

    private static func decode<Value: Decodable>(
        _: Value.Type, from object: Any, convertingSnakeCase: Bool
    ) throws -> Value {
        let decoder = JSONDecoder()
        if convertingSnakeCase { decoder.keyDecodingStrategy = .convertFromSnakeCase }
        return try decoder.decode(Value.self, from: JSONSerialization.data(withJSONObject: object))
    }
}
