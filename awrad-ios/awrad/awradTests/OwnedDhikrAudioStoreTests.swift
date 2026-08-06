import Foundation
import Testing
@testable import awrad

struct OwnedDhikrAudioStoreTests {
    @Test func rejectsExactTenMillionByteLimitAndAcceptsBelow() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OwnedDhikrAudioStore(rootDirectory: root)

        let exactLimit = try writeTempFile(named: "exact.m4a", byteCount: Int(OwnedDhikrAudioStore.maxByteSize))
        defer { try? FileManager.default.removeItem(at: exactLimit) }
        #expect(throws: OwnedDhikrAudioError.fileTooLarge) {
            try store.stageImport(from: exactLimit, suggestedExtension: "m4a")
        }

        let underLimit = try writeTempFile(named: "under.m4a", byteCount: Int(OwnedDhikrAudioStore.maxByteSize - 1))
        defer { try? FileManager.default.removeItem(at: underLimit) }

        // Codec inspection needs a real media file; inject a validator for size-path coverage.
        let staged = try store.stageImport(
            from: underLimit,
            suggestedExtension: "m4a",
            inspector: .init(
                inspect: { _ in
                    OwnedDhikrAudioInspection(
                        mimeType: "audio/mp4",
                        durationMs: 1_000,
                        sha256: String(repeating: "a", count: 64)
                    )
                }
            )
        )
        #expect(staged.byteSize == OwnedDhikrAudioStore.maxByteSize - 1)
        #expect(FileManager.default.fileExists(atPath: staged.temporaryURL.path))
        try store.discardStaged(staged)
    }

    @Test func rejectsUnsupportedExtensionAndDurationOverTenMinutes() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OwnedDhikrAudioStore(rootDirectory: root)

        let flac = try writeTempFile(named: "clip.flac", byteCount: 100)
        defer { try? FileManager.default.removeItem(at: flac) }
        #expect(throws: OwnedDhikrAudioError.unsupportedFormat) {
            try store.stageImport(
                from: flac,
                suggestedExtension: "flac",
                inspector: .init(inspect: { _ in
                    OwnedDhikrAudioInspection(mimeType: "audio/flac", durationMs: 1_000, sha256: "b")
                })
            )
        }

        let longClip = try writeTempFile(named: "long.mp3", byteCount: 100)
        defer { try? FileManager.default.removeItem(at: longClip) }
        #expect(throws: OwnedDhikrAudioError.durationTooLong) {
            try store.stageImport(
                from: longClip,
                suggestedExtension: "mp3",
                inspector: .init(inspect: { _ in
                    OwnedDhikrAudioInspection(
                        mimeType: "audio/mpeg",
                        durationMs: OwnedDhikrAudioStore.maxDurationMs + 1,
                        sha256: String(repeating: "c", count: 64)
                    )
                })
            )
        }
    }

    @Test func commitReplaceRemovesOldFileOnlyAfterSuccess() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OwnedDhikrAudioStore(rootDirectory: root)

        let firstSource = try writeTempFile(named: "first.wav", byteCount: 32)
        defer { try? FileManager.default.removeItem(at: firstSource) }
        let firstStaged = try store.stageImport(
            from: firstSource,
            suggestedExtension: "wav",
            inspector: .init(inspect: { _ in
                OwnedDhikrAudioInspection(
                    mimeType: "audio/wav",
                    durationMs: 500,
                    sha256: String(repeating: "d", count: 64)
                )
            })
        )
        let firstAsset = try store.commitStaged(firstStaged, dhikrID: UUID())
        let firstOwnedURL = try store.ownedFileURL(for: firstAsset)
        #expect(FileManager.default.fileExists(atPath: firstOwnedURL.path))

        let secondSource = try writeTempFile(named: "second.mp3", byteCount: 48)
        defer { try? FileManager.default.removeItem(at: secondSource) }
        let secondStaged = try store.stageImport(
            from: secondSource,
            suggestedExtension: "mp3",
            inspector: .init(inspect: { _ in
                OwnedDhikrAudioInspection(
                    mimeType: "audio/mpeg",
                    durationMs: 750,
                    sha256: String(repeating: "e", count: 64)
                )
            })
        )

        // Before commit, old file must still exist.
        #expect(FileManager.default.fileExists(atPath: firstOwnedURL.path))
        let replacement = try store.commitStaged(secondStaged, dhikrID: firstAsset.dhikrID, replacing: firstAsset)
        #expect(replacement.relativeFileName != firstAsset.relativeFileName)
        #expect(!FileManager.default.fileExists(atPath: firstOwnedURL.path))
        #expect(FileManager.default.fileExists(atPath: try store.ownedFileURL(for: replacement).path))
    }

    @Test func removeClearsOwnedFileAndStartupCleansOrphansAndTemps() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OwnedDhikrAudioStore(rootDirectory: root)

        let source = try writeTempFile(named: "keep.m4a", byteCount: 24)
        defer { try? FileManager.default.removeItem(at: source) }
        let staged = try store.stageImport(
            from: source,
            suggestedExtension: "m4a",
            inspector: .init(inspect: { _ in
                OwnedDhikrAudioInspection(
                    mimeType: "audio/mp4",
                    durationMs: 200,
                    sha256: String(repeating: "f", count: 64)
                )
            })
        )
        let asset = try store.commitStaged(staged, dhikrID: UUID())
        try store.removeOwnedFile(for: asset)
        #expect(!FileManager.default.fileExists(atPath: try store.ownedFileURL(for: asset).path))

        let orphanName = "\(UUID().uuidString.lowercased()).mp3"
        let orphanURL = try store.ownedDirectory().appendingPathComponent(orphanName)
        try Data(repeating: 1, count: 8).write(to: orphanURL)
        let staleTemp = try store.temporaryDirectory().appendingPathComponent("stale.tmp")
        try Data(repeating: 2, count: 8).write(to: staleTemp)

        try store.reconcileOrphans(
            referencedRelativeFileNames: [],
            now: Date(),
            orphanGrace: 0
        )
        #expect(!FileManager.default.fileExists(atPath: orphanURL.path))
        #expect(!FileManager.default.fileExists(atPath: staleTemp.path))
    }

    @Test func rejectsPathTraversalRelativeNames() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OwnedDhikrAudioStore(rootDirectory: root)
        #expect(throws: OwnedDhikrAudioError.invalidRelativeFileName) {
            _ = try store.ownedFileURL(
                for: DhikrAudioAsset(
                    id: UUID(),
                    dhikrID: UUID(),
                    relativeFileName: "../escape.mp3",
                    mimeType: "audio/mpeg",
                    byteSize: 1,
                    durationMs: 1,
                    sha256: String(repeating: "0", count: 64),
                    source: .import,
                    createdAt: Date()
                )
            )
        }
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("owned-audio-\(UUID().uuidString)", isDirectory: true)
    }

    private func writeTempFile(named name: String, byteCount: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)-\(name)")
        try Data(repeating: 7, count: byteCount).write(to: url)
        return url
    }
}
