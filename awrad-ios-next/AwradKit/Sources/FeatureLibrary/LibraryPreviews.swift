#if DEBUG
    import AwradDomain
    import Foundation

    /// Content for previews: a custom dhikr, two tags and a conflict on the dhikr.
    enum PreviewContent {
        static let morning = UserTag(id: .random(), name: "Morning", normalizedName: "morning")
        static let family = UserTag(id: .random(), name: "Family", normalizedName: "family")
        static let custom = CustomDhikr(
            id: .random(),
            document: CustomDhikrDocument(
                kind: .dua, arabic: "اللَّهُمَّ بَارِكْ لَنَا فِي يَوْمِنَا",
                title: LanguageTexts(en: "Morning blessing", ar: "بركة الصباح"),
                transliteration: LanguageTexts(en: "Allahumma barik lana fi yawmina"),
                translation: LanguageTexts(en: "O Allah, bless this day for us."),
                references: [Reference.other(id: "ref-1", text: "From my grandmother", url: nil).json]))

        /// Both tags on the custom dhikr, no conflicts, no notices.
        static let personal = PersonalContent(
            customDhikrs: [custom], tags: [family, morning], tagsByDhikr: [custom.id: [morning.id]])

        /// The same with the custom dhikr changed on another device.
        static var conflicted: PersonalContent {
            var content = personal
            content.conflicts = [
                SyncConflict(
                    key: SyncEntityKey(.customDhikr, custom.id), localOp: .put,
                    server: ServerCopy(version: 2, state: .active, document: nil))
            ]
            content.notices = [
                SyncNotice(code: .tagNameTaken, key: SyncEntityKey(.userTag, morning.id))
            ]
            return content
        }
    }

    /// A `PersonalLibrary` for previews: it serves the content it was given and accepts every edit
    /// without changing it.
    actor PreviewPersonalLibrary: PersonalLibrary {
        private let personal: PersonalContent

        init(_ personal: PersonalContent = .empty) {
            self.personal = personal
        }

        func content() -> PersonalContent { personal }

        nonisolated func updates() -> AsyncStream<PersonalContent> {
            let personal = personal
            return AsyncStream { continuation in
                continuation.yield(personal)
                continuation.finish()
            }
        }

        func saveCustomDhikr(
            id: AwradID?, document: CustomDhikrDocument, audio: AudioChange
        ) -> AwradID {
            id ?? .random()
        }

        func deleteCustomDhikr(_ id: AwradID) {}

        func createTag(named name: String) -> UserTag {
            UserTag(id: .random(), name: name, normalizedName: name.lowercased())
        }

        func renameTag(_ id: AwradID, to name: String) {}
        func deleteTag(_ id: AwradID) {}
        func setTags(_ tagIDs: [AwradID], on dhikr: AwradID) {}
        func resolveConflict(_ key: SyncEntityKey, choice: ConflictChoice) {}
        func dismissNotice(_ notice: SyncNotice) {}
        func dismissAudioNotice(_ notice: AudioUploadNotice) {}

        func stageAudio(from source: URL) -> StagedAudio { StagedAudio(url: source) }

        func audioURL(for dhikr: AwradID) -> URL? { nil }

        func downloadAudio(for dhikr: AwradID) throws(AudioDownloadError) -> URL { throw .unavailable }
    }
#endif
