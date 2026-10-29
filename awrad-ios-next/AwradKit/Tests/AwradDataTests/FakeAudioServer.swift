import AwradDomain
import CryptoKit
import Foundation

@testable import AwradData

/// The four audio operations in memory, following contracts/audio/v1 closely enough for the engine
/// tests: the upload rules in order, idempotent reservations by `asset_id`, completion that compares
/// the stored object with the reservation (`upload_incomplete`, `upload_mismatch`), download links
/// to ready assets only, and usage. Confirmed assets are told to the change queue's fake, so a put
/// naming one applies. One account.
actor FakeAudioServer: AudioServer {
    static let bucket = "https://r2.example/awrad-private-dhikr/"

    let account: AwradID
    let objects: FakeObjectStore
    let sync: FakeSyncServer?
    var limitBytes = AudioUploadRules.accountLimitBytes
    /// Bytes other recordings of the account already use.
    var otherUsedBytes = 0
    /// Failures for the next calls, in order.
    var failures: [AudioServerFailure] = []
    /// Refusals for the next reservations or completions that would otherwise succeed, in order.
    var createRefusals: [AudioRefusal] = []
    var completeRefusals: [AudioRefusal] = []
    private(set) var pending: [String: AudioUploadRequestWire] = [:]
    private(set) var ready: [String: AudioAssetWire] = [:]
    /// Every call, by operation ID.
    private(set) var calls: [String] = []

    init(account: AwradID, objects: FakeObjectStore, sync: FakeSyncServer?) {
        self.account = account
        self.objects = objects
        self.sync = sync
    }

    func fail(_ failure: AudioServerFailure) { failures.append(failure) }
    func refuseCreate(_ code: String, usage: AudioUsage? = nil) {
        createRefusals.append(AudioRefusal(code: code, usage: usage))
    }
    func refuseComplete(_ code: String) { completeRefusals.append(AudioRefusal(code: code)) }
    func setUsage(other: Int, limit: Int = AudioUploadRules.accountLimitBytes) {
        otherUsedBytes = other
        limitBytes = limit
    }

    /// A recording another device uploaded: ready, with its bytes in storage.
    func addAsset(_ data: Data, contentType: AudioContentType) async -> UploadedAudio {
        let id = AwradID.random()
        let asset = AudioAssetWire(
            assetID: id.description, byteSize: data.count, contentType: contentType.rawValue, status: "ready",
            createdAt: "2026-10-29T08:01:12Z")
        ready[asset.assetID] = asset
        await objects.store(data, asset: asset.assetID)
        await sync?.addReadyAsset(asset)
        return UploadedAudio(assetID: id, byteSize: data.count, contentType: contentType, durationMilliseconds: nil)
    }

    /// The cleanup job removed an asset.
    func forget(_ assetID: AwradID) async {
        ready[assetID.description] = nil
        await sync?.removeReadyAsset(assetID.description)
    }

    // MARK: - AudioServer

    func createUpload(_ request: AudioUploadRequestWire, account: AwradID) throws(AudioServerFailure)
        -> AudioCreateResponseWire
    {
        try check("create_audio_upload", account)
        let id = request.assetID
        if let asset = ready[id] {
            guard asset.byteSize == request.byteSize, asset.contentType == request.contentType else {
                throw .refused(AudioRefusal(code: "asset_id_in_use"))
            }
            return .ready(AudioAssetResultWire(asset: asset))
        }
        if let earlier = pending[id], earlier != request { throw .refused(AudioRefusal(code: "asset_id_in_use")) }
        if pending[id] == nil {
            let usage = usage
            if let error = AudioUploadRules.check(
                byteSize: request.byteSize, contentType: request.contentType, usedBytes: usage.usedBytes,
                limitBytes: usage.limitBytes)
            {
                throw .refused(AudioRefusal(code: error.rawValue, usage: error == .storageFull ? usage : nil))
            }
            if !createRefusals.isEmpty { throw .refused(createRefusals.removeFirst()) }
            pending[id] = request
        }
        let digest = Data(
            (0..<32).map { index in
                UInt8(request.sha256.dropFirst(index * 2).prefix(2), radix: 16) ?? 0
            })
        return .upload(
            AudioUploadWire(
                assetID: id, uploadURL: "\(Self.bucket)\(id)?X-Amz-Signature=\(calls.count)",
                uploadHeaders: [
                    "content-type": request.contentType, "x-amz-checksum-sha256": digest.base64EncodedString(),
                ],
                expiresAt: "2026-10-29T08:15:00Z"))
    }

    func completeUpload(_ assetID: AwradID, account: AwradID) async throws(AudioServerFailure)
        -> AudioAssetResultWire
    {
        try check("complete_audio_upload", account)
        let id = assetID.description
        if let asset = ready[id] { return AudioAssetResultWire(asset: asset) }
        guard let request = pending[id] else { throw .refused(AudioRefusal(code: "not_found")) }
        if !completeRefusals.isEmpty { throw .refused(completeRefusals.removeFirst()) }
        guard let data = await objects.object(id) else { throw .refused(AudioRefusal(code: "upload_incomplete")) }
        let sha = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard data.count == request.byteSize, sha == request.sha256 else {
            await objects.remove(id)
            pending[id] = nil
            throw .refused(AudioRefusal(code: "upload_mismatch"))
        }
        let asset = AudioAssetWire(
            assetID: id, byteSize: request.byteSize, contentType: request.contentType, status: "ready",
            createdAt: "2026-10-29T08:01:12Z")
        pending[id] = nil
        ready[id] = asset
        await sync?.addReadyAsset(asset)
        return AudioAssetResultWire(asset: asset)
    }

    func downloadLink(_ assetID: AwradID, account: AwradID) throws(AudioServerFailure) -> AudioDownloadWire {
        try check("get_audio_download", account)
        guard ready[assetID.description] != nil else { throw .refused(AudioRefusal(code: "not_found")) }
        return AudioDownloadWire(url: "\(Self.bucket)\(assetID)?X-Amz-Expires=600", expiresAt: "2026-10-29T09:10:00Z")
    }

    func usage(account: AwradID) throws(AudioServerFailure) -> AudioUsageWire {
        try check("get_audio_usage", account)
        return AudioUsageWire(usedBytes: usage.usedBytes, limitBytes: usage.limitBytes)
    }

    private var usage: AudioUsage {
        let used = pending.values.map(\.byteSize).reduce(0, +) + ready.values.map(\.byteSize).reduce(0, +)
        return AudioUsage(usedBytes: otherUsedBytes + used, limitBytes: limitBytes)
    }

    private func check(_ operation: String, _ account: AwradID) throws(AudioServerFailure) {
        calls.append(operation)
        if !failures.isEmpty { throw failures.removeFirst() }
        guard account == self.account else { throw .sync(.accountMismatch) }
    }
}

/// Private storage in memory, reached by the fake's signed links: objects by asset ID, every `PUT`
/// with its headers, and scripted trouble (a failed, lost or corrupted `PUT`; failing downloads).
actor FakeObjectStore: ObjectStore {
    private(set) var objects: [String: Data] = [:]
    private(set) var puts: [(url: URL, headers: [String: String])] = []
    private(set) var downloads = 0
    /// Failures for the next `PUT`s, in order.
    var putFailures: [ObjectStoreFailure] = []
    /// The next `PUT` reports success but stores nothing (so completing finds no object).
    var losesNextPut = false
    /// The next `PUT` stores other bytes (so completing finds a mismatch).
    var corruptsPuts = 0
    var failsDownloads = false

    func failPut(_ failure: ObjectStoreFailure) { putFailures.append(failure) }
    func loseNextPut() { losesNextPut = true }
    func corruptNextPuts(_ count: Int) { corruptsPuts = count }
    func setFailsDownloads(_ fails: Bool) { failsDownloads = fails }
    func store(_ data: Data, asset: String) { objects[asset] = data }
    func object(_ asset: String) -> Data? { objects[asset] }
    func remove(_ asset: String) { objects[asset] = nil }

    func put(_ file: URL, to url: URL, headers: [String: String]) throws(ObjectStoreFailure) {
        puts.append((url, headers))
        if !putFailures.isEmpty { throw putFailures.removeFirst() }
        guard let data = try? Data(contentsOf: file) else { throw .status(400) }
        if losesNextPut {
            losesNextPut = false
            return
        }
        let asset = url.lastPathComponent
        if corruptsPuts > 0 {
            corruptsPuts -= 1
            objects[asset] = data + Data("x".utf8)
        } else {
            objects[asset] = data
        }
    }

    func download(_ url: URL) throws(ObjectStoreFailure) -> URL {
        downloads += 1
        if failsDownloads { throw .transport }
        guard let data = objects[url.lastPathComponent] else { throw .status(404) }
        let file = FileManager.default.temporaryDirectory.appending(path: "download-\(AwradID.random())")
        do {
            try data.write(to: file)
        } catch {
            throw .transport
        }
        return file
    }
}
