import Foundation

// A custom dhikr's recording as its document names it (contracts/sync/v1 `audio`, slice 3c):
// none, one kept on the phone that imported it, or one uploaded to the account's private storage
// (contracts/audio/v1, root ADR-2026-10-29).

/// The two media types a recording may have, exactly as written on the wire.
public enum AudioContentType: String, CaseIterable, Sendable, Hashable {
    /// MP3.
    case mpeg = "audio/mpeg"
    /// M4A/AAC.
    case mp4 = "audio/mp4"

    /// The type of an imported file, from its extension: `.mp3` is `audio/mpeg`, `.m4a`
    /// `audio/mp4` (contracts/audio/v1 README, "Media types on import"). Anything else is `nil`.
    public init?(fileExtension: String) {
        switch fileExtension.lowercased() {
        case "mp3": self = .mpeg
        case "m4a": self = .mp4
        default: return nil
        }
    }

    /// The type the system reports for an imported file: `audio/mpeg`, or `audio/mp4` and its alias
    /// `audio/x-m4a` (contracts/audio/v1 README, "Phones": Importing). Anything else, raw AAC
    /// (`audio/aac`) included, is `nil`.
    public init?(importedMediaType mediaType: String) {
        switch mediaType.lowercased() {
        case "audio/mpeg": self = .mpeg
        case "audio/mp4", "audio/x-m4a": self = .mp4
        default: return nil
        }
    }

    /// The extension a file of this type is stored under.
    public var fileExtension: String {
        switch self {
        case .mpeg: "mp3"
        case .mp4: "m4a"
        }
    }
}

/// A recording uploaded to the account (`$defs/uploaded_audio`): a ready asset's ID, its size and
/// type (copied from the asset), and the length the importing phone measured.
public struct UploadedAudio: Hashable, Sendable {
    public let assetID: AwradID
    /// 1 to 10,000,000.
    public let byteSize: Int
    public let contentType: AudioContentType
    /// At least 1, or `nil` when the importing client couldn't measure it.
    public let durationMilliseconds: Int?

    public init(assetID: AwradID, byteSize: Int, contentType: AudioContentType, durationMilliseconds: Int?) {
        self.assetID = assetID
        self.byteSize = byteSize
        self.contentType = contentType
        self.durationMilliseconds = durationMilliseconds
    }

    private static let members: Set<String> = ["asset_id", "byte_size", "content_type", "duration_ms"]
    /// 2^53 - 1, the largest JSON integer (contracts/api/STYLE.md §5).
    private static let maxDuration = 9_007_199_254_740_991

    /// The shape from JSON, if it is exactly one: every member present, nothing else.
    public init?(json: AwradJSON) {
        guard let object = json.objectValue, Set(object.keys) == Self.members,
            let assetID = object["asset_id"]?.stringValue.flatMap(AwradID.init),
            let byteSize = object["byte_size"]?.intValue, (1...AudioUploadRules.maxFileBytes).contains(byteSize),
            let contentType = object["content_type"]?.stringValue.flatMap(AudioContentType.init(rawValue:))
        else { return nil }
        let duration = object["duration_ms"]
        if duration != .null {
            guard let milliseconds = duration?.intValue, (1...Self.maxDuration).contains(milliseconds) else {
                return nil
            }
        }
        self.init(
            assetID: assetID, byteSize: byteSize, contentType: contentType,
            durationMilliseconds: duration?.intValue)
    }

    public var json: AwradJSON {
        .object([
            "asset_id": .string(assetID.description),
            "byte_size": .int(byteSize),
            "content_type": .string(contentType.rawValue),
            "duration_ms": durationMilliseconds.map(AwradJSON.int) ?? .null,
        ])
    }
}

/// A custom dhikr's recording, when it has one.
public enum CustomDhikrAudio: Hashable, Sendable {
    /// `{"local_only": true}`: only on the phone that imported it (signed out, offline, or not
    /// uploaded yet).
    case localOnly
    /// In the account's private storage, playable on every device.
    case uploaded(UploadedAudio)

    /// The recording a non-null `audio` member names, or `nil` if it is neither shape.
    public init?(json: AwradJSON) {
        if json == .object(["local_only": .bool(true)]) {
            self = .localOnly
        } else if let uploaded = UploadedAudio(json: json) {
            self = .uploaded(uploaded)
        } else {
            return nil
        }
    }

    public var json: AwradJSON {
        switch self {
        case .localOnly: .object(["local_only": .bool(true)])
        case .uploaded(let uploaded): uploaded.json
        }
    }

    /// The uploaded recording, if it is one.
    public var uploaded: UploadedAudio? {
        if case .uploaded(let uploaded) = self { return uploaded }
        return nil
    }
}
