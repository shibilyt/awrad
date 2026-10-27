import AwradTesting
import Foundation
import Testing

/// Reads a file of contracts/design-tokens/v1 from the repository, so the generated Swift is checked
/// against the contract itself at run time, not against the generator.
enum DesignTokenContract {
    /// A file of contracts/design-tokens/v1, such as `icons.json`.
    static func url(_ file: String) throws -> URL {
        try FixtureLoader.contractsDirectory(holding: "design-tokens").appending(path: "design-tokens/v1/\(file)")
    }

    static func json(_ name: String) throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url("\(name).json")))
        return try #require(object as? [String: Any], "\(name).json isn't an object")
    }

    static func object(_ value: Any?, _ label: String) throws -> [String: Any] {
        try #require(value as? [String: Any], "\(label) isn't an object")
    }

    static func number(_ value: Any?, _ label: String) throws -> Double {
        try #require((value as? NSNumber)?.doubleValue, "\(label) isn't a number")
    }

    static func string(_ value: Any?, _ label: String) throws -> String {
        try #require(value as? String, "\(label) isn't a string")
    }

    /// A scale key as its Swift name: `2xl` is `xl2`.
    static func swiftName(_ key: String) -> String {
        guard let first = key.first, first.isNumber else { return key }
        return String(key.dropFirst()) + String(first)
    }

    /// `KeyValuePairs` as a dictionary, failing on a duplicate name.
    static func dictionary<Value>(_ pairs: KeyValuePairs<String, Value>) -> [String: Value] {
        Dictionary(pairs.map { ($0.key, $0.value) }, uniquingKeysWith: { first, _ in first })
    }
}
