import AwradDomain
import AwradTesting
import Foundation
import Testing

@testable import FeatureLibrary

/// Fixtures for the tests of the user's own dhikrs and tags.
enum Personal {
    static func custom(
        _ title: String = "Glory be", arabic: String = "سبحان الله", kind: DhikrKind = .dhikr,
        translation: String? = nil
    ) -> CustomDhikr {
        CustomDhikr(
            id: .random(),
            document: CustomDhikrDocument(
                kind: kind, arabic: arabic, title: LanguageTexts(en: title),
                translation: LanguageTexts(en: translation)))
    }

    static func tag(_ name: String) -> UserTag {
        UserTag(id: .random(), name: name, normalizedName: name.lowercased())
    }

    static func conflict(_ type: SyncEntityType, _ id: AwradID) -> SyncConflict {
        SyncConflict(
            key: SyncEntityKey(type, id), localOp: .put, server: ServerCopy(version: 2, state: .active, document: nil))
    }

    static let recording = URL(filePath: "/tmp/awrad-test/recording.m4a")

    /// A document the editor accepts.
    static func document(
        arabic: String = "سبحان الله", title: String = "Glory be", hasLocalAudio: Bool = false
    ) -> CustomDhikrDocument {
        CustomDhikrDocument(
            kind: .dhikr, arabic: arabic, title: LanguageTexts(en: title), hasLocalAudio: hasLocalAudio)
    }

    @MainActor
    static func catalogDhikr(_ key: String) throws -> Dhikr {
        try #require(try DhikrCatalog.bundled().dhikr(key))
    }
}
