import Foundation

/// A custom dhikr document that isn't valid, with every problem.
public struct CustomDhikrValidationError: Error, Hashable, Sendable {
    public let errors: [SyncFieldError]
}

/// Which custom dhikr documents are valid (contracts/sync/v1/fixtures/custom_dhikr_validity.json):
/// exactly those matching `$defs/custom_dhikr_document`. Errors are `{field, code}` with `field` a
/// JSON Pointer into the document, sorted by field, then code. Lengths are Unicode code points, and
/// "blank" is the schema's `\S` test (ECMAScript white space), as the server's validator reads it.
public enum CustomDhikrValidation {
    public static let maxTitleLength = 120
    public static let maxTextLength = 5000
    public static let maxReferences = 20

    private static let required = ["kind", "arabic", "title", "transliteration", "translation", "audio", "references"]

    /// Every problem with `json` as a custom dhikr document; empty when it's valid.
    public static func errors(in json: AwradJSON) -> [SyncFieldError] {
        guard let members = json.objectValue else { return [SyncFieldError(field: "", code: "invalid")] }
        var errors: [SyncFieldError] = []
        for key in members.keys where !required.contains(key) {
            errors.append(SyncFieldError(field: "/\(key)", code: "not_allowed"))
        }
        for key in required where members[key] == nil {
            errors.append(SyncFieldError(field: "/\(key)", code: "required"))
        }
        if let kind = members["kind"], kind.stringValue.flatMap(DhikrKind.init(rawValue:)) == nil {
            errors.append(SyncFieldError(field: "/kind", code: "invalid"))
        }
        if let arabic = members["arabic"] {
            errors += textErrors(arabic, field: "/arabic", maxLength: maxTextLength, nullable: false)
        }
        if let title = members["title"] {
            errors += languageErrors(title, field: "/title", keys: ["en", "ar", "ml"], maxLength: maxTitleLength)
            if let texts = title.objectValue, !texts.values.contains(where: { $0.stringValue != nil }) {
                errors.append(SyncFieldError(field: "/title", code: "required"))
            }
        }
        if let transliteration = members["transliteration"] {
            errors += languageErrors(
                transliteration, field: "/transliteration", keys: ["en", "ml"], maxLength: maxTextLength)
        }
        if let translation = members["translation"] {
            errors += languageErrors(
                translation, field: "/translation", keys: ["en", "ar", "ml"], maxLength: maxTextLength)
        }
        if let audio = members["audio"], audio != .null, audio != .object(["local_only": .bool(true)]) {
            errors.append(SyncFieldError(field: "/audio", code: "invalid"))
        }
        if let references = members["references"] {
            errors += referenceErrors(references)
        }
        return errors.sorted()
    }

    /// Whether `json` matches the catalog's reference shape (`$defs/reference`).
    public static func isValidReference(_ json: AwradJSON) -> Bool {
        guard let members = json.objectValue, let type = members["type"]?.stringValue,
            let shape = referenceShapes[type]
        else { return false }
        let allowed = Set(
            ["id", "type"] + shape.required + shape.optional + shape.integers.map(\.key)
                + (type == "other" ? ["url"] : []))
        guard members.keys.allSatisfy(allowed.contains),
            (["id"] + shape.required + shape.integers.map(\.key)).allSatisfy({ members[$0] != nil }),
            let id = members["id"]?.stringValue, isKey(id)
        else { return false }
        for key in shape.required + shape.optional where members[key] != nil {
            guard let text = members[key]?.stringValue, !isBlank(text) else { return false }
        }
        for (key, range) in shape.integers {
            guard let value = members[key]?.intValue, range.contains(value) else { return false }
        }
        if let url = members["url"] {
            guard let string = url.stringValue, let parsed = URL(string: string), parsed.scheme != nil else {
                return false
            }
        }
        return true
    }

    /// The schema's `\S`: true when every scalar is ECMAScript white space or a line terminator.
    public static func isBlank(_ text: String) -> Bool {
        text.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 0x09...0x0D, 0x20, 0xA0, 0x1680, 0x2000...0x200A, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000, 0xFEFF:
                true
            default:
                false
            }
        }
    }

    // MARK: - Parts

    private static func textErrors(
        _ value: AwradJSON, field: String, maxLength: Int, nullable: Bool
    ) -> [SyncFieldError] {
        switch value {
        case .null where nullable:
            return []
        case .string(let text):
            if isBlank(text) { return [SyncFieldError(field: field, code: "blank")] }
            if text.unicodeScalars.count > maxLength { return [SyncFieldError(field: field, code: "too_long")] }
            return []
        default:
            return [SyncFieldError(field: field, code: "invalid")]
        }
    }

    private static func languageErrors(
        _ value: AwradJSON, field: String, keys: [String], maxLength: Int
    ) -> [SyncFieldError] {
        guard let texts = value.objectValue else { return [SyncFieldError(field: field, code: "invalid")] }
        var errors: [SyncFieldError] = []
        for key in texts.keys where !keys.contains(key) {
            errors.append(SyncFieldError(field: "\(field)/\(key)", code: "not_allowed"))
        }
        for key in keys {
            guard let text = texts[key] else {
                errors.append(SyncFieldError(field: "\(field)/\(key)", code: "required"))
                continue
            }
            errors += textErrors(text, field: "\(field)/\(key)", maxLength: maxLength, nullable: true)
        }
        return errors
    }

    private static func referenceErrors(_ value: AwradJSON) -> [SyncFieldError] {
        guard let items = value.arrayValue else { return [SyncFieldError(field: "/references", code: "invalid")] }
        var errors: [SyncFieldError] = []
        if items.count > maxReferences { errors.append(SyncFieldError(field: "/references", code: "too_many")) }
        for (index, item) in items.enumerated() where !isValidReference(item) {
            errors.append(SyncFieldError(field: "/references/\(index)", code: "invalid"))
        }
        return errors
    }

    /// The catalog's `key` pattern, `^[a-z0-9]+(-[a-z0-9]+)*$`.
    static func isKey(_ text: String) -> Bool {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        return parts.allSatisfy { part in
            !part.isEmpty && part.unicodeScalars.allSatisfy { ("a"..."z").contains($0) || ("0"..."9").contains($0) }
        }
    }

    private struct ReferenceShape {
        let required: [String]
        let optional: [String]
        let integers: [(key: String, range: ClosedRange<Int>)]
    }

    private static let referenceShapes: [String: ReferenceShape] = [
        "quran": ReferenceShape(
            required: [], optional: [],
            integers: [("surah", 1...114), ("ayah_start", 1...Int.max), ("ayah_end", 1...Int.max)]),
        "hadith": ReferenceShape(required: ["collection"], optional: ["number", "narrator", "grade"], integers: []),
        "book": ReferenceShape(required: ["title"], optional: ["author", "volume", "page"], integers: []),
        "shaykh": ReferenceShape(required: ["name"], optional: ["note"], integers: []),
        "other": ReferenceShape(required: ["text"], optional: [], integers: []),
    ]
}
