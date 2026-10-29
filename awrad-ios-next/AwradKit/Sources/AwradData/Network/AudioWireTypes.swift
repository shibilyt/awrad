import AwradDomain
import Foundation

// Hand-written wire types of the four audio operations (contracts/api/paths/audio.yaml,
// contracts/audio/v1/audio.schema.json, root ADR-2026-10-16). Signed links and their headers are
// opaque: the client passes them through and never stores them.

/// The body of `create_audio_upload` (`$defs/upload_request`).
struct AudioUploadRequestWire: Codable, Equatable, Sendable {
    let assetID: String
    let byteSize: Int
    let contentType: String
    /// The file's SHA-256 in 64 lowercase hex digits.
    let sha256: String

    enum CodingKeys: String, CodingKey {
        case sha256
        case assetID = "asset_id"
        case byteSize = "byte_size"
        case contentType = "content_type"
    }
}

/// A pending upload's signed `PUT` link (`$defs/upload`): 15 minutes, with the headers to send.
struct AudioUploadWire: Codable, Equatable, Sendable {
    let assetID: String
    let uploadURL: String
    /// Sent with the `PUT` exactly as given: `content-type` and `x-amz-checksum-sha256` today.
    let uploadHeaders: [String: String]
    let expiresAt: String

    enum CodingKeys: String, CodingKey {
        case assetID = "asset_id"
        case uploadURL = "upload_url"
        case uploadHeaders = "upload_headers"
        case expiresAt = "expires_at"
    }
}

/// A confirmed recording of the account (`$defs/asset`).
struct AudioAssetWire: Codable, Equatable, Sendable {
    let assetID: String
    let byteSize: Int
    let contentType: String
    /// Always `ready`.
    let status: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case status
        case assetID = "asset_id"
        case byteSize = "byte_size"
        case contentType = "content_type"
        case createdAt = "created_at"
    }

    /// The document's `audio` for this asset: its size and type, and the length the phone measured.
    func uploadedAudio(durationMilliseconds: Int?) -> UploadedAudio? {
        guard let id = AwradID(assetID), let type = AudioContentType(rawValue: contentType),
            (1...AudioUploadRules.maxFileBytes).contains(byteSize)
        else { return nil }
        return UploadedAudio(
            assetID: id, byteSize: byteSize, contentType: type, durationMilliseconds: durationMilliseconds)
    }
}

/// `{asset}`: the body of `complete_audio_upload`, and of a repeated create once the asset is ready.
struct AudioAssetResultWire: Codable, Equatable, Sendable {
    let asset: AudioAssetWire
}

/// Every success body of `create_audio_upload`: a signed link while pending, or the asset once
/// ready (then the client skips the `PUT` and the completion).
enum AudioCreateResponseWire: Codable, Equatable, Sendable {
    case upload(AudioUploadWire)
    case ready(AudioAssetResultWire)

    private enum CodingKeys: String, CodingKey {
        case asset
    }

    init(from decoder: any Decoder) throws {
        if try decoder.container(keyedBy: CodingKeys.self).contains(.asset) {
            self = .ready(try AudioAssetResultWire(from: decoder))
        } else {
            self = .upload(try AudioUploadWire(from: decoder))
        }
    }

    func encode(to encoder: any Encoder) throws {
        switch self {
        case .upload(let upload): try upload.encode(to: encoder)
        case .ready(let result): try result.encode(to: encoder)
        }
    }
}

/// The body of `get_audio_download`: a signed `GET` link, valid for 10 minutes.
struct AudioDownloadWire: Codable, Equatable, Sendable {
    let url: String
    let expiresAt: String

    enum CodingKeys: String, CodingKey {
        case url
        case expiresAt = "expires_at"
    }
}

/// The body of `get_audio_usage`.
struct AudioUsageWire: Codable, Equatable, Sendable {
    let usedBytes: Int
    let limitBytes: Int

    enum CodingKeys: String, CodingKey {
        case usedBytes = "used_bytes"
        case limitBytes = "limit_bytes"
    }

    var usage: AudioUsage { AudioUsage(usedBytes: usedBytes, limitBytes: limitBytes) }
}
