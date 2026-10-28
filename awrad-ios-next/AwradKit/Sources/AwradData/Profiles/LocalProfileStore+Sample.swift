#if DEBUG
    import AwradDomain
    import Foundation

    // Sample data for simulator screenshots (debug builds only): custom dhikrs, tags on built-in and
    // custom dhikrs, and one open conflict, written straight into the active profile as if synced.
    extension LocalProfileStore {
        /// Fixed IDs, so launch arguments can open what the sample holds.
        public enum Sample {
            public static let hasbiyallah = AwradID("0192f0d0-0000-7000-8000-000000000001") ?? .random()
            public static let morningDua = AwradID("0192f0d0-0000-7000-8000-000000000002") ?? .random()
            public static let morning = AwradID("0192f0a0-0000-7000-8000-000000000001") ?? .random()
            public static let evening = AwradID("0192f0a0-0000-7000-8000-000000000002") ?? .random()
            public static let travel = AwradID("0192f0a0-0000-7000-8000-000000000003") ?? .random()
            /// A built-in dhikr the sample tags (Surat al-Ikhlas).
            static let ikhlas = AwradID("c88b9491-40ad-4b42-a5b8-e07c4b4d31ef") ?? .random()
        }

        /// Fills an empty active profile with the sample.
        public func seedSample() async {
            guard !(registry.active?.hasData ?? false), await !database.summary().hasData else { return }
            try? await database.seed(Self.sampleSeed())
            await refreshSummary()
            await publishAll()
        }

        static func sampleSeed() -> ProfileDatabase.Seed {
            let hasbiyallah = CustomDhikrDocument(
                kind: .dua, arabic: "حَسْبِيَ ٱللَّهُ لَآ إِلَٰهَ إِلَّا هُوَ عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ ٱلْعَرْشِ ٱلْعَظِيمِ",
                title: LanguageTexts(en: "Hasbiyallah", ar: "حسبي الله", ml: "ഹസ്ബിയല്ലാഹ്"),
                transliteration: LanguageTexts(en: "Hasbiyallahu la ilaha illa huwa, 'alayhi tawakkaltu"),
                translation: LanguageTexts(en: "Allah is sufficient for me; there is no god but Him. In Him I trust."),
                references: [Reference.quran(id: "quran-9-129", surah: 9, ayahs: 129...129).json])
            var theirs = hasbiyallah
            theirs.title = LanguageTexts(en: "Hasbiyallah (seven times)")
            let morningDua = CustomDhikrDocument(
                kind: .dhikr, arabic: "أَصْبَحْنَا وَأَصْبَحَ ٱلْمُلْكُ لِلَّهِ",
                title: LanguageTexts(en: "Asbahna wa asbahal mulk"),
                translation: LanguageTexts(en: "We have entered the morning and the dominion belongs to Allah"))
            let tag = { (name: String) in
                SyncDocument.userTag(UserTagDocument(name: name, normalizedName: name.lowercased()))
            }
            let tags = { (ids: [AwradID]) in SyncDocument.dhikrPersonal(DhikrPersonalDocument(tagIDs: ids)) }
            return ProfileDatabase.Seed(
                documents: [
                    (SyncEntityKey(.customDhikr, Sample.hasbiyallah), .customDhikr(hasbiyallah)),
                    (SyncEntityKey(.customDhikr, Sample.morningDua), .customDhikr(morningDua)),
                    (SyncEntityKey(.userTag, Sample.morning), tag("Morning")),
                    (SyncEntityKey(.userTag, Sample.evening), tag("Evening")),
                    (SyncEntityKey(.userTag, Sample.travel), tag("Travel")),
                    (SyncEntityKey(.dhikrPersonal, Sample.hasbiyallah), tags([Sample.morning, Sample.evening])),
                    (SyncEntityKey(.dhikrPersonal, Sample.morningDua), tags([Sample.morning])),
                    (SyncEntityKey(.dhikrPersonal, Sample.ikhlas), tags([Sample.morning, Sample.evening])),
                ],
                conflicts: [
                    SyncConflict(
                        key: SyncEntityKey(.customDhikr, Sample.hasbiyallah), localOp: .put,
                        server: ServerCopy(version: 2, state: .active, document: .customDhikr(theirs)))
                ])
        }
    }

    extension ProfileDatabase {
        struct Seed: Sendable {
            let documents: [(SyncEntityKey, SyncDocument)]
            let conflicts: [SyncConflict]
        }

        /// Writes documents and conflicts as already synced (version 1), with no commands.
        func seed(_ seed: Seed) throws {
            let state = SwiftDataSyncState(context: modelContext)
            for (key, document) in seed.documents {
                state.setDocument(document, for: key)
                state.setKnownVersion(1, for: key)
            }
            for conflict in seed.conflicts { state.setConflict(conflict, for: conflict.key) }
            try modelContext.save()
        }
    }
#endif
