import AwradDomain
import CryptoKit
import Foundation

/// One entry of a profile's upload queue (`AudioUploadRecord`): a custom dhikr's recording on its
/// way to the account's private storage (contracts/audio/v1 README, "Uploading").
struct PendingUpload: Equatable, Sendable {
    enum Stage: String, Sendable {
        /// Reserve the upload (`create_audio_upload`), then `PUT` the file.
        case reserve
        /// The file is in storage: confirm it (`complete_audio_upload`).
        case complete
        /// The asset is ready: point the dhikr at it.
        case attach
        /// It can't be uploaded (`failure`): the recording stays on the phone.
        case failed
    }

    let dhikrID: AwradID
    var assetID: AwradID
    /// The file, under the profile's `Audio/` directory.
    var fileName: String
    var sha256: String
    var byteSize: Int
    var contentType: String
    var durationMilliseconds: Int?
    var stage = Stage.reserve
    var reserved = false
    var mismatchRetries = 0
    var failure: AudioUploadFailure?

    /// The request that reserves it.
    var request: AudioUploadRequestWire {
        AudioUploadRequestWire(
            assetID: assetID.description, byteSize: byteSize, contentType: contentType, sha256: sha256)
    }

    /// Starts over under a new asset, with the file as it is now (after a mismatch, or an ID in use).
    mutating func restart(with file: AudioFileFacts) {
        assetID = .random()
        sha256 = file.sha256
        byteSize = file.byteSize
        stage = .reserve
        reserved = false
    }
}

extension PendingUpload {
    init?(_ record: AudioUploadRecord) {
        guard let stage = Stage(rawValue: record.stage) else { return nil }
        self.init(
            dhikrID: AwradID(record.dhikrID), assetID: AwradID(record.assetID), fileName: record.fileName,
            sha256: record.sha256, byteSize: record.byteSize, contentType: record.contentType,
            durationMilliseconds: record.durationMilliseconds, stage: stage, reserved: record.reserved,
            mismatchRetries: record.mismatchRetries, failure: record.failure.flatMap(AudioUploadFailure.init))
    }

    func write(to record: AudioUploadRecord) {
        record.assetID = assetID.value
        record.fileName = fileName
        record.sha256 = sha256
        record.byteSize = byteSize
        record.contentType = contentType
        record.durationMilliseconds = durationMilliseconds
        record.stage = stage.rawValue
        record.reserved = reserved
        record.mismatchRetries = mismatchRetries
        record.failure = failure?.rawValue
    }
}

/// What the upload needs to know about a file: its size and SHA-256 (CryptoKit, read in chunks).
struct AudioFileFacts: Equatable, Sendable {
    let byteSize: Int
    /// 64 lowercase hex digits.
    let sha256: String

    private static let chunk = 1 << 20

    init(byteSize: Int, sha256: String) {
        self.byteSize = byteSize
        self.sha256 = sha256
    }

    /// Reads the file; `nil` if it can't be read.
    init?(file: URL) {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        var size = 0
        do {
            // `nil` or empty at the end of the file.
            while let data = try handle.read(upToCount: Self.chunk), !data.isEmpty {
                hasher.update(data: data)
                size += data.count
            }
        } catch {
            return nil
        }
        self.init(byteSize: size, sha256: hasher.finalize().map { String(format: "%02x", $0) }.joined())
    }
}
