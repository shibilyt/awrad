import AwradDomain
import Foundation

// A profile's recordings on disk (slice 3c), beside 3b's imported files:
//
// - `Audio/<dhikr-id>.mp3|m4a`: a recording imported on this phone, until it's uploaded;
// - `Audio/Cache/<asset-id>.mp3|m4a`: an uploaded recording, linked from the imported file when its
//   upload completes or downloaded on its first play, and played from there afterwards, offline too;
// - `Audio/Cache/Partial/`: downloads on their way into the cache.
//
// `sweepAudio` removes what no document names any more: the cached copy of a replaced, removed or
// deleted recording, and an imported file whose dhikr's recording is now uploaded or gone.
extension ProfileFiles {
    func cacheDirectory(_ profile: AwradID) -> URL {
        audioDirectory(profile).appending(path: "Cache", directoryHint: .isDirectory)
    }

    func cacheURL(_ audio: UploadedAudio, profile: AwradID) -> URL {
        cacheDirectory(profile).appending(path: "\(audio.assetID).\(audio.contentType.fileExtension)")
    }

    /// The uploaded recording's copy on this phone, if there is one.
    func cachedAudio(_ audio: UploadedAudio, profile: AwradID) -> URL? {
        let url = cacheURL(audio, profile: profile)
        return FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) ? url : nil
    }

    /// Where each custom dhikr's recording is on this phone: its imported file, else the cached copy
    /// of its uploaded recording. Dhikrs with neither are absent.
    func recordingFiles(_ audio: [AwradID: CustomDhikrAudio], profile: AwradID) -> [AwradID: URL] {
        var files: [AwradID: URL] = [:]
        for (dhikr, recording) in audio {
            if let imported = audioURL(for: dhikr, profile: profile) {
                files[dhikr] = imported
            } else if let uploaded = recording.uploaded, let cached = cachedAudio(uploaded, profile: profile) {
                files[dhikr] = cached
            }
        }
        return files
    }

    /// Keeps the bytes of an imported recording as its asset's cached copy once the upload is
    /// confirmed (a hard link, so no second copy on disk).
    func cacheUploaded(_ file: URL, as audio: UploadedAudio, profile: AwradID) {
        let destination = cacheURL(audio, profile: profile)
        let manager = FileManager.default
        guard !manager.fileExists(atPath: destination.path(percentEncoded: false)) else { return }
        try? manager.createDirectory(at: cacheDirectory(profile), withIntermediateDirectories: true)
        if (try? manager.linkItem(at: file, to: destination)) == nil {
            try? manager.copyItem(at: file, to: destination)
        }
    }

    /// Makes `file` the dhikr's imported recording again, so it can be uploaded under a new asset
    /// (an `audio_not_found` or `audio_mismatch` rejection).
    func restoreImported(_ file: URL, for dhikr: AwradID, profile: AwradID) {
        guard audioURL(for: dhikr, profile: profile) == nil else { return }
        let destination = audioDirectory(profile).appending(path: "\(dhikr).\(file.pathExtension.lowercased())")
        if (try? FileManager.default.linkItem(at: file, to: destination)) == nil {
            try? FileManager.default.copyItem(at: file, to: destination)
        }
    }

    /// Moves a finished download into the cache: first next to it, then renamed into place, so a
    /// cached file is always whole. A copy already in place (a play that finished first) is
    /// replaced atomically; on any failure nothing is left in `Partial/`.
    func storeDownload(_ download: URL, as audio: UploadedAudio, profile: AwradID) throws -> URL {
        let manager = FileManager.default
        let partial = cacheDirectory(profile).appending(path: "Partial", directoryHint: .isDirectory)
        let staging = partial.appending(path: AwradID.random().description)
        let destination = cacheURL(audio, profile: profile)
        do {
            try manager.createDirectory(at: partial, withIntermediateDirectories: true)
            try manager.moveItem(at: download, to: staging)
            do {
                try manager.moveItem(at: staging, to: destination)
            } catch CocoaError.fileWriteFileExists {
                _ = try manager.replaceItemAt(destination, withItemAt: staging)
            }
            return destination
        } catch {
            try? manager.removeItem(at: staging)
            try? manager.removeItem(at: download)
            throw error
        }
    }

    /// Removes recordings no document needs: cached copies of assets no custom dhikr names, and
    /// imported files of dhikrs whose recording isn't local-only (uploaded, removed or deleted)
    /// unless an upload of them is still under way.
    func sweepAudio(_ audio: [AwradID: CustomDhikrAudio], uploading: Set<AwradID>, profile: AwradID) {
        let manager = FileManager.default
        let named = Set(audio.values.compactMap { $0.uploaded.map { "\($0.assetID).\($0.contentType.fileExtension)" } })
        let cached = (try? manager.contentsOfDirectory(at: cacheDirectory(profile), includingPropertiesForKeys: nil))
        for file in cached ?? [] where !file.hasDirectoryPath && !named.contains(file.lastPathComponent) {
            try? manager.removeItem(at: file)
        }
        let imported = (try? manager.contentsOfDirectory(at: audioDirectory(profile), includingPropertiesForKeys: nil))
        for file in imported ?? [] where Self.audioExtensions.contains(file.pathExtension.lowercased()) {
            guard let dhikr = AwradID(file.deletingPathExtension().lastPathComponent),
                audio[dhikr] != .localOnly, !uploading.contains(dhikr)
            else { continue }
            try? manager.removeItem(at: file)
        }
    }
}
