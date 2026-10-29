import AwradDomain
import Foundation
import SwiftData

// A profile's upload queue and its "couldn't be uploaded" notices (slice 3c). Each change saves
// once; pointing a dhikr at its uploaded recording queues the put in the same transaction.
extension ProfileDatabase {
    /// The upload queue, oldest first, failed entries included.
    func uploads() -> [PendingUpload] {
        let sort = [SortDescriptor(\AudioUploadRecord.createdAt), SortDescriptor(\AudioUploadRecord.dhikrID)]
        let records = (try? modelContext.fetch(FetchDescriptor<AudioUploadRecord>(sortBy: sort))) ?? []
        return records.compactMap(PendingUpload.init)
    }

    /// Queues a recording for upload, replacing the dhikr's earlier entry.
    func addUpload(_ upload: PendingUpload, now: Date) throws {
        uploadRecord(upload.dhikrID).map(modelContext.delete)
        modelContext.insert(AudioUploadRecord(upload, createdAt: now))
        try modelContext.save()
    }

    /// Saves an entry's progress. Returns `false`, saving nothing, when the dhikr's entry is no longer
    /// the one for `asset` (its recording was replaced or removed meanwhile).
    @discardableResult
    func updateUpload(_ upload: PendingUpload, asset: AwradID) throws -> Bool {
        guard let record = uploadRecord(upload.dhikrID), record.assetID == asset.value else { return false }
        upload.write(to: record)
        try modelContext.save()
        return true
    }

    /// Drops a dhikr's entry (its recording was replaced or removed, or the dhikr deleted).
    func removeUpload(for dhikr: AwradID) throws {
        guard let record = uploadRecord(dhikr) else { return }
        modelContext.delete(record)
        try modelContext.save()
    }

    /// A recording that can't be uploaded: its entry stays, failed, so it isn't tried again until
    /// the recording changes, and the user gets a notice.
    func failUpload(_ upload: PendingUpload, asset: AwradID, notice: AudioUploadNotice) throws {
        guard let record = uploadRecord(upload.dhikrID), record.assetID == asset.value else { return }
        var failed = upload
        failed.stage = .failed
        failed.failure = notice.failure
        failed.write(to: record)
        var last = FetchDescriptor<AudioNoticeRecord>(sortBy: [SortDescriptor(\.position, order: .reverse)])
        last.fetchLimit = 1
        let position = ((try? modelContext.fetch(last).first?.position) ?? 0) + 1
        modelContext.insert(
            AudioNoticeRecord(
                position: position, dhikrID: notice.dhikrID.value, failure: notice.failure.rawValue,
                usedBytes: notice.usage?.usedBytes, limitBytes: notice.usage?.limitBytes))
        try modelContext.save()
    }

    /// Points the dhikr at its uploaded recording and queues the put naming it, in one transaction
    /// with removing the entry. Returns `false` (removing the entry only) when the dhikr is gone or
    /// no longer has a recording waiting to upload.
    func attachUpload(_ upload: PendingUpload, audio: UploadedAudio, queue: Bool) throws -> Bool {
        guard let record = uploadRecord(upload.dhikrID), record.assetID == audio.assetID.value else { return false }
        modelContext.delete(record)
        var state = SwiftDataSyncState(context: modelContext)
        let key = SyncEntityKey(.customDhikr, upload.dhikrID)
        guard case .customDhikr(var document)? = state.document(key), document.audio == .localOnly else {
            try modelContext.save()
            return false
        }
        document.audio = .uploaded(audio)
        SyncRules.save(.put(.customDhikr(document), id: upload.dhikrID), queue: queue, in: &state)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
        return true
    }

    /// Every custom dhikr's recording, by dhikr.
    func customAudio() -> [AwradID: CustomDhikrAudio] {
        var audio: [AwradID: CustomDhikrAudio] = [:]
        for record in (try? modelContext.fetch(FetchDescriptor<CustomDhikrRecord>())) ?? [] {
            guard let json = try? AwradJSON.decode(record.document),
                let recording = json["audio"].flatMap(CustomDhikrAudio.init(json:))
            else { continue }
            audio[AwradID(record.id)] = recording
        }
        return audio
    }

    // MARK: - Notices

    func audioNotices() -> [AudioUploadNotice] {
        let sort = [SortDescriptor(\AudioNoticeRecord.position)]
        let records = (try? modelContext.fetch(FetchDescriptor<AudioNoticeRecord>(sortBy: sort))) ?? []
        return records.compactMap { record in
            AudioUploadFailure(rawValue: record.failure).map { failure in
                let usage = record.usedBytes.flatMap { used in
                    record.limitBytes.map { AudioUsage(usedBytes: used, limitBytes: $0) }
                }
                return AudioUploadNotice(dhikrID: AwradID(record.dhikrID), failure: failure, usage: usage)
            }
        }
    }

    func dismiss(_ notice: AudioUploadNotice) throws {
        let id = notice.dhikrID.value
        let failure = notice.failure.rawValue
        let matching = FetchDescriptor<AudioNoticeRecord>(
            predicate: #Predicate { $0.dhikrID == id && $0.failure == failure })
        for record in (try? modelContext.fetch(matching)) ?? [] { modelContext.delete(record) }
        try modelContext.save()
    }

    private func uploadRecord(_ dhikr: AwradID) -> AudioUploadRecord? {
        let id = dhikr.value
        var descriptor = FetchDescriptor<AudioUploadRecord>(predicate: #Predicate { $0.dhikrID == id })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }
}
