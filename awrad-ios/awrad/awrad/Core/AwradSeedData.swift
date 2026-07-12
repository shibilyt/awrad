import Foundation

enum AwradSeedData {
    static let dhikrs: [Dhikr] = [
        Dhikr(
            title: "Surah Ikhlas",
            arabic: "بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ\nقُلۡ هُوَ ٱللَّهُ أَحَدٌ\nٱللَّهُ ٱلصَّمَدُ\nلَمۡ يَلِدۡ وَلَمۡ يُولَدۡ\nوَلَمۡ يَكُن لَّهُۥ كُفُوًا أَحَدُۢ",
            transliteration: "Qul huwa Allahu ahad",
            translation: "Surah Ikhlas",
            audioURL: URL(string: "https://dhikrs.awrad.app/ikhlas.mp3"),
            audioFileName: "ikhlas.mp3",
            category: .quran,
            audioCountPerPlay: 1,
            benefits: ["Recited for protection, focus, and remembrance."]
        ),
        Dhikr(
            title: "Tahleel",
            arabic: "لَا إِلٰهَ إِلَّا ٱللَّٰهُ",
            transliteration: "La ilaha illallah",
            translation: "There is no god but Allah.",
            audioURL: URL(string: "https://dhikrs.awrad.app/1736077531573-g8kajuv6fww-tahleel.mp3"),
            audioFileName: "tahleel.mp3",
            category: .praise,
            audioCountPerPlay: 2,
            benefits: ["The foundation phrase of tawhid.", "A strong daily remembrance for focus and renewal."]
        ),
        Dhikr(
            title: "Ya Wahhabu",
            arabic: "يَا وَهَّابُ",
            transliteration: "Ya Wahhabu",
            translation: "O Bestower.",
            audioURL: URL(string: "https://dhikrs.awrad.app/ya-wahhabu-2.mp3"),
            audioFileName: "ya-wahhabu.mp3",
            category: .praise,
            audioCountPerPlay: 2
        ),
        Dhikr(
            title: "Isthighfar",
            arabic: "أَسْتَغْفِرُ ٱللَّٰهَ ٱلْعَظِيمَ",
            transliteration: "Asthaghfirullahil Azeem",
            translation: "I seek forgiveness from Allah, the Magnificent.",
            audioURL: URL(string: "https://dhikrs.awrad.app/1736083253280-c2kcxrk9cj-isthighfar.mp3"),
            audioFileName: "isthighfar.mp3",
            category: .forgiveness,
            benefits: ["A daily practice for repentance and humility."]
        ),
        Dhikr(
            title: "Swalath Al Fathimiyya",
            arabic: "اللَّهُمَّ صَلِّ عَلَى النُّورِ وَأَهْلِهِ",
            transliteration: "Allahumma swalli ala nnoori wa ahlihi",
            translation: "O Allah, send blessings upon the Light and his family.",
            audioURL: URL(string: "https://dhikrs.awrad.app/1736075795464-yh0twy42m-swalath-fatimiya.mp3"),
            audioFileName: "swalath-fatimiya.mp3",
            category: .swalaths
        ),
        Dhikr(
            title: "Swalath",
            arabic: "صَلَّى ٱللَّٰهُ عَلَىٰ مُحَمَّدٍ، صَلَّى ٱللَّٰهُ عَلَيْهِ وَسَلَّمَ",
            transliteration: "Swallallahu ala Muhammad, swallallahu alayhi wa sallim",
            translation: "May Allah bless Muhammad and grant him peace.",
            audioURL: URL(string: "https://dhikrs.awrad.app/1736510596621-oqiqm8yj15l-swalath-regular.mp3"),
            audioFileName: "swalath-regular.mp3",
            category: .swalaths
        ),
        Dhikr(
            title: "Swalath 2",
            arabic: "اللَّهُمَّ صَلِّ عَلَىٰ سَيِّدِنَا مُحَمَّدٍ وَعَلَىٰ آلِهِ وَصَحْبِهِ وَسَلِّمْ",
            transliteration: "Allahumma swalli ala sayyidina Muhammadin wa ala aalihi wa swahbihi wa sallim",
            translation: "O Allah, send blessings and peace upon our master Muhammad, his family, and companions.",
            audioURL: URL(string: "https://dhikrs.awrad.app/1737527316685-7gkeld0j3oy-swalath-1.mp3"),
            audioFileName: "swalath-1.mp3",
            category: .swalaths
        ),
        Dhikr(
            title: "Swalath al Fatih",
            arabic: "اللَّهُمَّ صَلِّ عَلَىٰ سَيِّدِنَا مُحَمَّدٍ ❁ الْفَاتِحِ لِمَا أُغْلِقَ ❁ وَالْخَاتِمِ لِمَا سَبَقَ ❁ نَاصِرِ الْحَقِّ بِالْحَقِّ ❁ وَالْهَادِي إِلَىٰ صِرَاطِكَ الْمُسْتَقِيمِ ❁ وَعَلَىٰ آلِهِ حَقَّ قَدْرِهِ وَمِقْدَارِهِ الْعَظِيمِ",
            transliteration: "Swalath al Fatih",
            translation: "Blessings upon our master Muhammad, the opener of what was closed.",
            audioURL: URL(string: "https://dhikrs.awrad.app/swalath_fatih.mp3"),
            audioFileName: "swalath-fatih.mp3",
            category: .swalaths
        ),
        Dhikr(
            title: "Swalath al Nariyya",
            arabic: "اللَّهُمَّ صَلِّ صَلَاةً كَامِلَةً وَسَلِّمْ سَلَامًا تَامًّا عَلَىٰ سَيِّدِنَا مُحَمَّدٍ الَّذِي تَنْحَلُّ بِهِ الْعُقَدُ وَتَنْفَرِجُ بِهِ الْكُرَبُ وَتُقْضَىٰ بِهِ الْحَوَائِجُ وَتُنَالُ بِهِ الرَّغَائِبُ وَحُسْنُ الْخَوَاتِمِ",
            transliteration: "Swalath al Nariyya",
            translation: "A complete prayer and peace upon our master Muhammad.",
            audioURL: URL(string: "https://dhikrs.awrad.app/swalath_nariyya.mp3"),
            audioFileName: "swalath-nariyya.mp3",
            category: .swalaths
        ),
        Dhikr(
            title: "Swalath for Debt",
            arabic: "اللَّهُمَّ صَلِّ عَلَىٰ مُحَمَّدٍ عَبْدِكَ وَرَسُولِكَ وَعَلَى الْمُؤْمِنِينَ وَالْمُسْلِمِينَ وَلِلْمُؤْمِنَاتِ وَالْمُسْلِمَاتِ",
            transliteration: "Allāhumma ṣalli ʿalā Muḥammadin ʿabdika wa rasūlika wa ʿalā al-muʾminīna wa al-muslimīna wa lil-muʾmināti wa al-muslimāt.",
            translation: "O Allah, send blessings upon Muhammad, Your servant and Your messenger, and upon the believing men and women.",
            audioURL: URL(string: "https://dhikrs.awrad.app/swalath_tajul_ulama.mp3"),
            audioFileName: "swalath_tajul_ulama.mp3",
            category: .swalaths
        ),
        Dhikr(
            title: "Ramadan Dhikr",
            arabic: "أَشْهَدُ أَنْ لَا إِلٰهَ إِلَّا ٱللَّٰهُ، أَسْتَغْفِرُ ٱللَّٰهَ، أَسْأَلُكَ ٱلْجَنَّةَ وَأَعُوذُ بِكَ مِنَ ٱلنَّارِ",
            transliteration: "Ash'hadu an la ilaha illallahu, asthaghfirullah, as'alukal jannatha wa au'dhu bika mina nnaar",
            translation: "I bear witness there is no god but Allah, seek forgiveness, ask for Paradise, and seek refuge from the Fire.",
            audioURL: URL(string: "https://dhikrs.awrad.app/ramadan_full.mp3"),
            audioFileName: "ramadan-full.mp3",
            category: .ramadan
        ),
        Dhikr(
            title: "First 10 Nights",
            arabic: "اللَّهُمَّ ٱرْحَمْنِي يَا أَرْحَمَ ٱلرَّاحِمِينَ",
            transliteration: "Allahummarhamni ya arhama rrahimin",
            translation: "O Allah, have mercy on me, Most Merciful of those who show mercy.",
            audioURL: URL(string: "https://dhikrs.awrad.app/ramadan_first10.mp3"),
            audioFileName: "ramadan-first10.mp3",
            category: .ramadan
        ),
        Dhikr(
            title: "Second 10 Nights",
            arabic: "اللَّهُمَّ ٱغْفِرْ لِي ذُنُوبِي يَا رَبَّ ٱلْعَالَمِينَ",
            transliteration: "Allahummaghfirli dhunubi ya rabbal aalameen",
            translation: "O Allah, forgive my sins, Lord of all worlds.",
            audioURL: URL(string: "https://dhikrs.awrad.app/ramadan_second10.mp3"),
            audioFileName: "ramadan-second10.mp3",
            category: .ramadan
        )
    ]

    static func defaultWirds() -> [Wird] {
        if let imported = loadBundledWirds(), !imported.isEmpty {
            return imported
        }
        let segments = [
            WirdSegment(
                kind: .dhikr,
                arabic: "بِسْمِ اللهِ الرَّحْمٰنِ الرَّحِيْمِ",
                transliteration: ["en": "Bismillahi r-Rahmani r-Rahim"],
                translation: ["en": "In the name of Allah, the Most Merciful, the Especially Merciful."],
                repeatSpec: RepeatSpec(count: 1)
            ),
            WirdSegment(
                kind: .salah,
                arabic: "اللَّهُمَّ صَلِّ عَلَى سَيِّدِنَا مُحَمَّدٍ",
                transliteration: ["en": "Allahumma salli ala Sayyidina Muhammad"],
                translation: ["en": "O Allah, bless our master Muhammad."],
                repeatSpec: RepeatSpec(count: 3)
            ),
            WirdSegment(
                kind: .dhikr,
                arabic: "أَسْتَغْفِرُ اللهَ",
                transliteration: ["en": "Astaghfirullah"],
                translation: ["en": "I seek forgiveness from Allah."],
                repeatSpec: RepeatSpec(count: 3)
            )
        ]
        let part = WirdPart(
            localizedTitle: ["en": "Daily Wird", "ar": "ورد اليوم"],
            localizedSubtitle: ["en": "Short daily reading", "ar": "قراءة يومية مختصرة"],
            segments: segments
        )
        return [
            Wird(
                slug: "daily-essentials",
                localizedName: ["en": "Daily Essentials", "ar": "الأوراد اليومية"],
                localizedDescription: ["en": "A compact daily wird for starting the Awrad experience.",
                                       "ar": "ورد يومي مختصر لبداية تجربة تطبيق أوراد."],
                author: "Awrad",
                tags: [.general],
                schedule: WirdSchedule(cadence: .everyDay),
                parts: [part]
            )
        ]
    }

    private static func loadBundledWirds() -> [Wird]? {
        let nested = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "Resources/Wirds") ?? []
        let root = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        let urls = Array(Set(nested + root)).sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard !urls.isEmpty else {
            return nil
        }
        let imported: [Wird] = urls.compactMap { url in
            guard let data = try? Data(contentsOf: url),
                  let json = try? JSONDecoder().decode(WirdJSON.self, from: data) else {
                return nil
            }
            return json.toWird()
        }
        return imported.isEmpty ? nil : imported
    }
}

// MARK: - Bundled wird JSON schema (see Resources/Wirds/README.md)

private struct WirdJSON: Decodable {
    var slug: String
    var version: Int?
    var sortOrder: Int?
    var name: [String: String]
    var description: [String: String]?
    var author: String?
    var sourceAttribution: String?
    var tags: [String]?
    var estimatedMinutes: Int?
    var schedule: ScheduleJSON?
    var parts: [PartJSON]

    func toWird() -> Wird {
        Wird(
            slug: slug,
            version: version ?? 1,
            sortOrder: sortOrder ?? 0,
            localizedName: name,
            localizedDescription: description ?? [:],
            author: author ?? "",
            sourceAttribution: sourceAttribution,
            tags: (tags ?? []).compactMap { WirdTag(rawValue: $0.lowercased()) },
            estimatedMinutes: estimatedMinutes,
            schedule: schedule?.toSchedule() ?? WirdSchedule(),
            parts: parts.map { $0.toPart() }
        )
    }
}

private struct ScheduleJSON: Decodable {
    var cadence: String?
    var daysOfWeek: [Int]?
    var intervalDays: Int?
    var intervalAnchor: String?
    var hijriAnchor: String?
    var defaultOccasion: OccasionJSON?

    func toSchedule() -> WirdSchedule {
        var schedule = WirdSchedule()
        switch (cadence ?? "EVERY_DAY").uppercased() {
        case "ROTATION":
            schedule.cadence = .rotation
        case "DAYS_OF_WEEK":
            schedule.cadence = .daysOfWeek(Set(daysOfWeek ?? []))
        case "INTERVAL":
            schedule.cadence = .interval(days: max(intervalDays ?? 1, 1), anchor: intervalAnchor ?? "2024-01-01")
        default:
            schedule.cadence = .everyDay
        }
        if let hijriAnchor { schedule.hijriAnchor = Self.parseHijri(hijriAnchor) }
        if let defaultOccasion { schedule.defaultOccasion = defaultOccasion.toOccasion() }
        return schedule
    }

    static func parseHijri(_ raw: String) -> HijriAnchor? {
        let parts = raw.uppercased().split(separator: ":")
        switch parts.first.map(String.init) {
        case "RAMADAN": return .ramadan
        case "LAST_TEN_NIGHTS": return .lastTenNights
        case "HIJRI_MONTH": return parts.count > 1 ? .hijriMonth(Int(parts[1]) ?? 1) : nil
        case "HIJRI_DATE": return parts.count > 2 ? .hijriDate(month: Int(parts[1]) ?? 1, day: Int(parts[2]) ?? 1) : nil
        default: return nil
        }
    }
}

private struct OccasionJSON: Decodable {
    var type: String
    var prayer: String?
    var startMinute: Int?
    var endMinute: Int?

    func toOccasion() -> WirdOccasion {
        switch type.uppercased() {
        case "AFTER_PRAYER": return .afterPrayer(Prayer(rawValue: (prayer ?? "fajr").lowercased()) ?? .fajr)
        case "MORNING": return .morning
        case "EVENING": return .evening
        case "BEFORE_SLEEP": return .beforeSleep
        case "TIME_WINDOW": return .timeWindow(startMinute: startMinute ?? 0, endMinute: endMinute ?? 1_440)
        default: return .anytime
        }
    }
}

private struct PartJSON: Decodable {
    var title: [String: String]
    var subtitle: [String: String]?
    var occasion: OccasionJSON?
    var blockRepeat: Int?
    var segments: [SegmentJSON]

    func toPart() -> WirdPart {
        WirdPart(
            localizedTitle: title,
            localizedSubtitle: subtitle ?? [:],
            occasion: occasion?.toOccasion(),
            blockRepeat: max(blockRepeat ?? 1, 1),
            segments: segments.map { $0.toSegment() }
        )
    }
}

private struct SegmentJSON: Decodable {
    var kind: String?
    var arabic: String?
    var transliteration: [String: String]?
    var translation: [String: String]?
    var text: [String: String]?
    var `repeat`: RepeatJSON?
    var fadl: [String: String]?
    var quran: QuranJSON?

    func toSegment() -> WirdSegment {
        WirdSegment(
            kind: SegmentKind(rawValue: (kind ?? "dhikr").lowercased()) ?? .dhikr,
            arabic: arabic ?? "",
            transliteration: transliteration ?? [:],
            translation: translation ?? [:],
            localizedText: text ?? [:],
            repeatSpec: `repeat`?.toSpec() ?? RepeatSpec(count: 1),
            quranRef: quran?.toRef(),
            fadl: fadl ?? [:]
        )
    }
}

private struct RepeatJSON: Decodable {
    var count: Int?
    var min: Int?
    var max: Int?
    func toSpec() -> RepeatSpec { RepeatSpec(count: count ?? min ?? 1, min: min, max: max) }
}

private struct QuranJSON: Decodable {
    var surah: Int
    var ayahStart: Int
    var ayahEnd: Int?
    func toRef() -> QuranRef { QuranRef(surah: surah, ayahStart: ayahStart, ayahEnd: ayahEnd) }
}
