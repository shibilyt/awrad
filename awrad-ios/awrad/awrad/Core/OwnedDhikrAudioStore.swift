import Foundation
import CryptoKit
import AVFoundation

struct OwnedDhikrAudioInspection: Equatable {
    var mimeType: String
    var durationMs: Int64
    var sha256: String
    /// When empty, `stageImport` keeps the caller-suggested extension after content validation.
    var preferredExtension: String = ""
}

struct OwnedDhikrAudioInspector: Sendable {
    var inspect: @Sendable (URL) throws -> OwnedDhikrAudioInspection

    nonisolated static let live = OwnedDhikrAudioInspector { url in
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        let digest = SHA256.hash(data: data)
        let sha = digest.map { String(format: "%02x", $0) }.joined()

        // AVFoundation must accept the bytes; never trust the path extension alone.
        let player: AVAudioPlayer
        do {
            player = try AVAudioPlayer(contentsOf: url)
        } catch {
            throw OwnedDhikrAudioError.corruptMedia
        }
        guard player.duration.isFinite, player.duration >= 0 else {
            throw OwnedDhikrAudioError.corruptMedia
        }
        let durationMs = Int64((player.duration * 1000).rounded(.down))

        guard let preferred = preferredAudioIdentity(fromPathExtension: url.pathExtension) else {
            throw OwnedDhikrAudioError.unsupportedFormat
        }

        return OwnedDhikrAudioInspection(
            mimeType: preferred.mimeType,
            durationMs: durationMs,
            sha256: sha,
            preferredExtension: preferred.fileExtension
        )
    }

    nonisolated private static func preferredAudioIdentity(fromPathExtension ext: String) -> (mimeType: String, fileExtension: String)? {
        switch ext.lowercased() {
        case "m4a", "mp4":
            return ("audio/mp4", "m4a")
        case "aac":
            return ("audio/mp4", "aac")
        case "mp3":
            return ("audio/mpeg", "mp3")
        case "wav":
            return ("audio/wav", "wav")
        default:
            return nil
        }
    }
}

enum OwnedDhikrAudioError: Error, Equatable {
    case fileTooLarge
    case durationTooLong
    case unsupportedFormat
    case corruptMedia
    case invalidRelativeFileName
    case missingOwnedFile
}

struct StagedOwnedDhikrAudio: Equatable {
    var temporaryURL: URL
    var relativeFileName: String
    var mimeType: String
    var byteSize: Int64
    var durationMs: Int64
    var sha256: String
}

final class OwnedDhikrAudioStore: @unchecked Sendable {
    static let maxByteSize: Int64 = 10_000_000
    static let maxDurationMs: Int64 = 10 * 60 * 1000
    static let acceptedExtensions: Set<String> = ["m4a", "aac", "mp3", "wav"]

    private let rootDirectory: URL
    private let fileManager: FileManager

    init(rootDirectory: URL, fileManager: FileManager = .default) {
        self.rootDirectory = rootDirectory
        self.fileManager = fileManager
    }

    func temporaryDirectory() throws -> URL {
        try ensureSubdirectory("tmp")
    }

    func ownedDirectory() throws -> URL {
        try ensureSubdirectory("owned")
    }

    func stageImport(
        from sourceURL: URL,
        suggestedExtension: String,
        inspector: OwnedDhikrAudioInspector = .live
    ) throws -> StagedOwnedDhikrAudio {
        let suggested = suggestedExtension.lowercased()
        guard Self.acceptedExtensions.contains(suggested) else {
            throw OwnedDhikrAudioError.unsupportedFormat
        }

        let attributes = try fileManager.attributesOfItem(atPath: sourceURL.path)
        let byteSize: Int64
        if let size = (attributes[.size] as? NSNumber)?.int64Value {
            byteSize = size
        } else {
            byteSize = Int64(try Data(contentsOf: sourceURL).count)
        }
        guard byteSize < Self.maxByteSize else {
            throw OwnedDhikrAudioError.fileTooLarge
        }

        let tmpDir = try temporaryDirectory()
        let provisionalName = "\(UUID().uuidString.lowercased()).\(suggested)"
        let temporaryURL = tmpDir.appendingPathComponent(provisionalName)
        if fileManager.fileExists(atPath: temporaryURL.path) {
            try fileManager.removeItem(at: temporaryURL)
        }

        guard let input = InputStream(url: sourceURL), let output = OutputStream(url: temporaryURL, append: false) else {
            throw OwnedDhikrAudioError.corruptMedia
        }
        input.open()
        output.open()
        defer {
            input.close()
            output.close()
        }

        var copied: Int64 = 0
        let bufferSize = 64 * 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while input.hasBytesAvailable {
            let read = input.read(buffer, maxLength: bufferSize)
            if read < 0 {
                try? fileManager.removeItem(at: temporaryURL)
                throw OwnedDhikrAudioError.corruptMedia
            }
            if read == 0 { break }
            copied += Int64(read)
            if copied >= Self.maxByteSize {
                try? fileManager.removeItem(at: temporaryURL)
                throw OwnedDhikrAudioError.fileTooLarge
            }
            let written = output.write(buffer, maxLength: read)
            if written != read {
                try? fileManager.removeItem(at: temporaryURL)
                throw OwnedDhikrAudioError.corruptMedia
            }
        }

        do {
            let inspection = try inspector.inspect(temporaryURL)
            let resolvedExtension = {
                let preferred = inspection.preferredExtension.lowercased()
                if Self.acceptedExtensions.contains(preferred) {
                    return preferred
                }
                return suggested
            }()
            guard Self.acceptedExtensions.contains(resolvedExtension) else {
                try? fileManager.removeItem(at: temporaryURL)
                throw OwnedDhikrAudioError.unsupportedFormat
            }
            guard Self.isAcceptedMIME(inspection.mimeType, extension: resolvedExtension) else {
                try? fileManager.removeItem(at: temporaryURL)
                throw OwnedDhikrAudioError.unsupportedFormat
            }
            guard inspection.durationMs <= Self.maxDurationMs else {
                try? fileManager.removeItem(at: temporaryURL)
                throw OwnedDhikrAudioError.durationTooLong
            }

            let relativeFileName: String
            let stagedURL: URL
            if resolvedExtension == suggested {
                relativeFileName = provisionalName
                stagedURL = temporaryURL
            } else {
                relativeFileName = "\(UUID().uuidString.lowercased()).\(resolvedExtension)"
                stagedURL = tmpDir.appendingPathComponent(relativeFileName)
                try fileManager.moveItem(at: temporaryURL, to: stagedURL)
            }

            return StagedOwnedDhikrAudio(
                temporaryURL: stagedURL,
                relativeFileName: relativeFileName,
                mimeType: inspection.mimeType,
                byteSize: copied,
                durationMs: inspection.durationMs,
                sha256: inspection.sha256
            )
        } catch let error as OwnedDhikrAudioError {
            try? fileManager.removeItem(at: temporaryURL)
            throw error
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw OwnedDhikrAudioError.corruptMedia
        }
    }

    func discardStaged(_ staged: StagedOwnedDhikrAudio) throws {
        if fileManager.fileExists(atPath: staged.temporaryURL.path) {
            try fileManager.removeItem(at: staged.temporaryURL)
        }
    }

    @discardableResult
    func commitStaged(
        _ staged: StagedOwnedDhikrAudio,
        dhikrID: AwradID,
        replacing previous: DhikrAudioAsset? = nil,
        assetID: AwradID = UUID(),
        createdAt: Date = Date()
    ) throws -> DhikrAudioAsset {
        let ownedDir = try ownedDirectory()
        let destination = ownedDir.appendingPathComponent(staged.relativeFileName)
        if fileManager.fileExists(atPath: destination.path) {
            // Idempotent retry: prior attempt already moved the bytes.
            if fileManager.fileExists(atPath: staged.temporaryURL.path) {
                try? fileManager.removeItem(at: staged.temporaryURL)
            }
        } else if fileManager.fileExists(atPath: staged.temporaryURL.path) {
            try fileManager.moveItem(at: staged.temporaryURL, to: destination)
        } else {
            throw OwnedDhikrAudioError.missingOwnedFile
        }

        let asset = DhikrAudioAsset(
            id: assetID,
            dhikrID: dhikrID,
            relativeFileName: staged.relativeFileName,
            mimeType: staged.mimeType,
            byteSize: staged.byteSize,
            durationMs: staged.durationMs,
            sha256: staged.sha256,
            source: .import,
            createdAt: createdAt
        )

        if let previous, previous.relativeFileName != asset.relativeFileName {
            try? removeOwnedFile(for: previous)
        }
        return asset
    }

    func removeOwnedFile(for asset: DhikrAudioAsset) throws {
        let url = try ownedFileURL(for: asset)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    func ownedFileURL(for asset: DhikrAudioAsset) throws -> URL {
        try ownedFileURL(relativeFileName: asset.relativeFileName)
    }

    func ownedFileURL(relativeFileName: String) throws -> URL {
        let name = relativeFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              !name.contains("/"),
              !name.contains("\\"),
              name != ".",
              name != "..",
              !name.contains("..") else {
            throw OwnedDhikrAudioError.invalidRelativeFileName
        }
        return try ownedDirectory().appendingPathComponent(name)
    }

    func resolvePlayableURL(for asset: DhikrAudioAsset) -> URL? {
        guard let url = try? ownedFileURL(for: asset),
              fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        return url
    }

    func reconcileOrphans(
        referencedRelativeFileNames: Set<String>,
        now: Date = Date(),
        orphanGrace: TimeInterval = 60 * 60
    ) throws {
        let owned = try ownedDirectory()
        let contents = try fileManager.contentsOfDirectory(
            at: owned,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        for url in contents {
            let name = url.lastPathComponent
            guard !referencedRelativeFileNames.contains(name) else { continue }
            let values = try url.resourceValues(forKeys: [.contentModificationDateKey])
            let modified = values.contentModificationDate ?? .distantPast
            guard now.timeIntervalSince(modified) >= orphanGrace else { continue }
            try? fileManager.removeItem(at: url)
        }

        let tmp = try temporaryDirectory()
        let temps = try fileManager.contentsOfDirectory(
            at: tmp,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        for url in temps {
            try? fileManager.removeItem(at: url)
        }
    }

    private func ensureSubdirectory(_ name: String) throws -> URL {
        let url = rootDirectory.appendingPathComponent(name, isDirectory: true)
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = url
        try mutableURL.setResourceValues(values)
        return url
    }

    private static func isAcceptedMIME(_ mimeType: String, extension ext: String) -> Bool {
        let normalized = mimeType.lowercased()
        switch ext {
        case "m4a", "aac":
            return normalized.contains("mp4") || normalized.contains("aac") || normalized.contains("m4a")
        case "mp3":
            return normalized.contains("mpeg") || normalized.contains("mp3")
        case "wav":
            return normalized.contains("wav") || normalized.contains("wave")
        default:
            return false
        }
    }
}
