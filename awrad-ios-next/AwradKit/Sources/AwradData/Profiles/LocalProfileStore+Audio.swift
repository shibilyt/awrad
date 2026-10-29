import AwradDomain
import Foundation

/// The audio operations and storage's signed links (slice 3c), wired in by the composition root.
public struct AudioServices: Sendable {
    let server: any AudioServer
    let objects: any ObjectStore
}

// Private audio in the active profile (slice 3c, root ADR-2026-10-29): uploads ride on the sync
// attempt (so only signed in, as the profile's account), playback downloads an uploaded recording
// once into the profile's files, and Settings reads the account's storage.
extension LocalProfileStore {
    /// Uploads, sends the queue and pulls the feed; if a put came back rejected for its recording,
    /// uploads that again and sends once more. Returns whether an upload must wait for a later try.
    func syncWithAudio(server: any SyncServer, account accountID: AwradID) async throws(SyncFailure) -> Bool {
        let database = self.database
        let profile = registry.activeProfileID
        let files = self.files
        var pass = SyncPass(server: server)
        pass.recordingFiles = { files.recordingFiles(await database.customAudio(), profile: profile) }
        var uploadsWait = false
        for _ in 0..<2 {
            uploadsWait = try await uploadRecordings(account: accountID)
            let result = try await pass.run(database, account: accountID)
            for (dhikr, file) in result.uploadsQueued {
                files.restoreImported(file, for: dhikr, profile: profile)
            }
            if result.uploadsQueued.isEmpty { break }
        }
        await refreshAudioUsage(account: accountID)
        await sweepAudio()
        return uploadsWait
    }

    private func uploadRecordings(account: AwradID) async throws(SyncFailure) -> Bool {
        guard let audio else { return false }
        let engine = AudioUploadEngine(server: audio.server, objects: audio.objects, files: files, now: now)
        return try await engine.run(database, profile: registry.activeProfileID, account: account).needsRetry
    }

    /// Reads the account's storage for Settings; a failure keeps the last reading.
    private func refreshAudioUsage(account: AwradID) async {
        guard let audio, let usage = try? await audio.server.usage(account: account) else { return }
        audioUsage = usage.usage
    }

    /// Removes recordings the active profile's documents no longer name.
    func sweepAudio() async {
        let uploading = Set(await database.uploads().filter { $0.stage != .failed }.map(\.dhikrID))
        files.sweepAudio(await database.customAudio(), uploading: uploading, profile: registry.activeProfileID)
    }

    // MARK: - PersonalLibrary

    public func dismissAudioNotice(_ notice: AudioUploadNotice) async {
        try? await database.dismiss(notice)
        await publishAll()
    }

    public func audioURL(for dhikr: AwradID) async -> URL? {
        let profile = registry.activeProfileID
        if let imported = files.audioURL(for: dhikr, profile: profile) { return imported }
        guard case .customDhikr(let document)? = await database.document(SyncEntityKey(.customDhikr, dhikr)),
            let uploaded = document.audio?.uploaded
        else { return nil }
        return files.cachedAudio(uploaded, profile: profile)
    }

    public func downloadAudio(for dhikr: AwradID) async throws(AudioDownloadError) -> URL {
        let profile = registry.activeProfileID
        guard case .customDhikr(let document)? = await database.document(SyncEntityKey(.customDhikr, dhikr)),
            let uploaded = document.audio?.uploaded
        else { throw .noRecording }
        if let cached = files.cachedAudio(uploaded, profile: profile) { return cached }
        guard let audio, registry.activeProfileMaySync, let accountID = registry.active?.accountID,
            await account.signedInAccount()?.id == accountID
        else { throw .unavailable }
        let link: AudioDownloadWire
        do {
            link = try await audio.server.downloadLink(uploaded.assetID, account: accountID)
        } catch .refused(let refusal) where refusal.code == "not_found" {
            throw .notFound
        } catch {
            throw .unavailable
        }
        guard let url = URL(string: link.url), let download = try? await audio.objects.download(url) else {
            throw .unavailable
        }
        do {
            return try files.storeDownload(download, as: uploaded, profile: profile)
        } catch {
            throw .unavailable
        }
    }
}
