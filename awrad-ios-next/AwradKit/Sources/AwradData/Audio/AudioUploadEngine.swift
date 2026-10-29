import AVFoundation
import AwradDomain
import Foundation

/// Uploads a profile's recordings (contracts/audio/v1 README, "Uploading" and "Phones"): reserve,
/// `PUT` the file to the signed link with exactly its headers, confirm, then point the dhikr at the
/// asset by queuing its put. It runs inside a sync attempt, so only while the profile's account is
/// signed in, and before the queue is sent, so the put goes out in the same pass.
///
/// | Answer | What happens |
/// |---|---|
/// | `413`, `415`, `invalid_size`, `storage_full` (or the same rule checked first on the phone) | The recording stays local, with a notice; the dhikr syncs without it |
/// | `storage_full`, on a later sync | Queued again once the usage endpoint shows room for it |
/// | `upload_incomplete`, a `PUT` storage refused, `404` on completing | Reserve again (a fresh link), `PUT` again, confirm again |
/// | `upload_mismatch` | Start over once under a new asset with the file as it is now; a second mismatch stays local, with a notice |
/// | `asset_id_in_use` | Start over under a new asset |
/// | Already ready on reserving | Skip the `PUT` and the confirmation |
struct AudioUploadEngine: Sendable {
    /// Steps one recording may take in a run before it waits for the next sync.
    static let maxSteps = 8

    let server: any AudioServer
    let objects: any ObjectStore
    let files: ProfileFiles
    let now: @Sendable () -> Date

    /// What a run did.
    struct Run: Equatable, Sendable {
        /// Recordings whose dhikr now names its asset (each queued a put).
        var attached = 0
        /// Some recording couldn't finish now (storage unreachable, too many retries): try later.
        var needsRetry = false
    }

    /// One run over the profile's queue. First every local-only recording with a file and no entry
    /// gets one (an import, "Add to my account", a rejected put's recording, a restart).
    func run(_ database: ProfileDatabase, profile: AwradID, account: AwradID) async throws(SyncFailure) -> Run {
        try await enqueueMissing(database, profile: profile)
        var context = Context(database: database, profile: profile, account: account)
        var run = Run()
        for queued in await database.uploads() {
            var upload = queued
            if upload.stage == .failed {
                guard try await retriesStorageFull(&upload, in: &context) else { continue }
            }
            switch try await advance(upload, in: &context) {
            case .attached: run.attached += 1
            case .retryLater: run.needsRetry = true
            case .done: break
            }
        }
        return run
    }

    // MARK: - The queue

    private func enqueueMissing(_ database: ProfileDatabase, profile: AwradID) async throws(SyncFailure) {
        let queued = Set(await database.uploads().map(\.dhikrID))
        for (dhikr, audio) in await database.customAudio() where audio == .localOnly && !queued.contains(dhikr) {
            guard let file = files.audioURL(for: dhikr, profile: profile), let facts = AudioFileFacts(file: file)
            else { continue }
            let type = AudioContentType(fileExtension: file.pathExtension)?.rawValue ?? "audio/\(file.pathExtension)"
            let upload = PendingUpload(
                dhikrID: dhikr, assetID: .random(), fileName: file.lastPathComponent, sha256: facts.sha256,
                byteSize: facts.byteSize, contentType: type,
                durationMilliseconds: await Self.durationMilliseconds(of: file))
            try await storage { try await database.addUpload(upload, now: now()) }
        }
    }

    /// The length of a recording in milliseconds, or `nil` when it can't be read.
    static func durationMilliseconds(of file: URL) async -> Int? {
        guard let duration = try? await AVURLAsset(url: file).load(.duration), duration.isNumeric else { return nil }
        let milliseconds = Int((duration.seconds * 1000).rounded())
        return milliseconds >= 1 ? milliseconds : nil
    }

    // MARK: - One recording

    private enum Outcome {
        case attached, retryLater, done
    }

    /// What a run shares: where it works, and the account's usage once read for the pre-check.
    private struct Context {
        let database: ProfileDatabase
        let profile: AwradID
        let account: AwradID
        var usage: AudioUsage??
    }

    private func advance(_ start: PendingUpload, in context: inout Context) async throws(SyncFailure) -> Outcome {
        var upload = start
        let file = files.audioDirectory(context.profile).appending(path: upload.fileName)
        for _ in 0..<Self.maxSteps {
            let asset = upload.assetID
            switch upload.stage {
            case .reserve:
                guard FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) else {
                    try await storage { try await context.database.removeUpload(for: upload.dhikrID) }
                    return .done
                }
                if !upload.reserved, let refusal = try await precheck(upload, in: &context) {
                    return try await fail(upload, asset: asset, refusal, in: context)
                }
                if let outcome = try await reserve(&upload, file: file, in: &context) { return outcome }
            case .complete:
                if let outcome = try await complete(&upload, file: file, in: context) { return outcome }
            case .attach:
                return try await attach(upload, file: file, in: context)
            case .failed:
                return .done
            }
            guard try await storage({ try await context.database.updateUpload(upload, asset: asset) }) else {
                return .done  // Replaced or removed meanwhile.
            }
        }
        return .retryLater
    }

    /// A `storage_full` failure goes back in the queue once the usage endpoint shows room for it
    /// (contracts/audio/v1 README, "Phones": Retries), and its notice goes. Other failures wait
    /// for the recording to change. Returns whether `upload` is queued again.
    private func retriesStorageFull(_ upload: inout PendingUpload, in context: inout Context) async throws(SyncFailure)
        -> Bool
    {
        guard upload.failure == .storageFull, let usage = try await usage(in: &context),
            AudioUploadRules.check(
                byteSize: upload.byteSize, contentType: upload.contentType, usedBytes: usage.usedBytes,
                limitBytes: usage.limitBytes) == nil
        else { return false }
        upload.stage = .reserve
        upload.failure = nil
        let retried = upload
        return try await storage { try await context.database.retryUpload(retried) }
    }

    /// The account's usage, read once a run; `nil` when it can't be read.
    private func usage(in context: inout Context) async throws(SyncFailure) -> AudioUsage? {
        if context.usage == nil {
            do {
                context.usage = .some(try await server.usage(account: context.account).usage)
            } catch .sync(let failure) {
                throw failure
            } catch {
                context.usage = .some(nil)
            }
        }
        return context.usage ?? nil
    }

    /// The upload rules, checked on the phone before reserving with the account's usage.
    private func precheck(_ upload: PendingUpload, in context: inout Context) async throws(SyncFailure)
        -> AudioRefusal?
    {
        let usage = try await usage(in: &context)
        guard
            let error = AudioUploadRules.check(
                byteSize: upload.byteSize, contentType: upload.contentType, usedBytes: usage?.usedBytes ?? 0,
                limitBytes: usage?.limitBytes ?? AudioUploadRules.accountLimitBytes)
        else { return nil }
        return AudioRefusal(code: error.rawValue, usage: error == .storageFull ? usage : nil)
    }

    /// Reserves the upload and `PUT`s the file. Returns an outcome when the recording is done for now.
    private func reserve(_ upload: inout PendingUpload, file: URL, in context: inout Context) async throws(SyncFailure)
        -> Outcome?
    {
        switch try await call({ () async throws(AudioServerFailure) in
            try await server.createUpload(upload.request, account: context.account)
        }) {
        case .success(.ready(let result)):
            upload.adopt(result.asset)
        case .success(.upload(let link)):
            if !upload.reserved, case .some(.some(let usage)) = context.usage {
                context.usage = .some(
                    AudioUsage(usedBytes: usage.usedBytes + upload.byteSize, limitBytes: usage.limitBytes))
            }
            upload.reserved = true
            guard let url = URL(string: link.uploadURL) else { return .retryLater }
            do {
                try await objects.put(file, to: url, headers: link.uploadHeaders)
                upload.stage = .complete
            } catch .transport {
                _ = try await storage { try await context.database.updateUpload(upload, asset: upload.assetID) }
                return .retryLater
            } catch {
                // Storage refused the PUT (an expired link): reserve again for a fresh one.
            }
        case .failure(let refusal) where refusal.uploadError != nil:
            return try await fail(upload, asset: upload.assetID, refusal, in: context)
        case .failure(let refusal) where refusal.code == "asset_id_in_use":
            guard let facts = AudioFileFacts(file: file) else { return .retryLater }
            upload.restart(with: facts)
        case .failure:
            return .retryLater
        }
        return nil
    }

    private func complete(_ upload: inout PendingUpload, file: URL, in context: Context) async throws(SyncFailure)
        -> Outcome?
    {
        switch try await call({ () async throws(AudioServerFailure) in
            try await server.completeUpload(upload.assetID, account: context.account)
        }) {
        case .success(let result):
            upload.adopt(result.asset)
        case .failure(let refusal) where refusal.code == "upload_incomplete" || refusal.code == "not_found":
            upload.stage = .reserve
        case .failure(let refusal) where refusal.code == "upload_mismatch":
            guard upload.mismatchRetries < 1 else {
                return try await fail(upload, asset: upload.assetID, AudioRefusal(code: refusal.code), in: context)
            }
            guard let facts = AudioFileFacts(file: file) else { return .retryLater }
            upload.restart(with: facts)
            upload.mismatchRetries += 1
        case .failure:
            return .retryLater
        }
        return nil
    }

    /// Keeps the file as the asset's cached copy, then points the dhikr at it with its put.
    private func attach(_ upload: PendingUpload, file: URL, in context: Context) async throws(SyncFailure) -> Outcome {
        guard let type = AudioContentType(rawValue: upload.contentType) else { return .retryLater }
        let audio = UploadedAudio(
            assetID: upload.assetID, byteSize: upload.byteSize, contentType: type,
            durationMilliseconds: upload.durationMilliseconds)
        if FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) {
            files.cacheUploaded(file, as: audio, profile: context.profile)
        }
        let attached = try await storage {
            try await context.database.attachUpload(upload, audio: audio, queue: true)
        }
        return attached ? .attached : .done
    }

    private func fail(
        _ upload: PendingUpload, asset: AwradID, _ refusal: AudioRefusal, in context: Context
    ) async throws(SyncFailure) -> Outcome {
        let failure = refusal.uploadError.map(AudioUploadFailure.init) ?? .uploadMismatch
        let notice = AudioUploadNotice(
            dhikrID: upload.dhikrID, failure: failure, usage: failure == .storageFull ? refusal.usage : nil)
        try await storage { try await context.database.failUpload(upload, asset: asset, notice: notice) }
        return .done
    }

    // MARK: - Helpers

    /// A server call whose refusals come back as values; every other failure ends the run.
    private func call<Wire>(_ request: () async throws(AudioServerFailure) -> Wire) async throws(SyncFailure)
        -> Result<Wire, AudioRefusal>
    {
        do throws(AudioServerFailure) {
            return .success(try await request())
        } catch {
            switch error {
            case .refused(let refusal): return .failure(refusal)
            case .sync(let failure): throw failure
            }
        }
    }

    /// A local write that failed: treated like an unavailable server, so the attempt is retried.
    private func storage<Value>(_ write: () async throws -> Value) async throws(SyncFailure) -> Value {
        do {
            return try await write()
        } catch {
            throw .unavailable
        }
    }
}

extension PendingUpload {
    /// The confirmed asset: its size and type are what the dhikr's document copies.
    fileprivate mutating func adopt(_ asset: AudioAssetWire) {
        byteSize = asset.byteSize
        contentType = asset.contentType
        stage = .attach
    }
}
