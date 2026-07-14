import Foundation

struct DhikrDisplayContent: Hashable {
    var title: String
    var translation: String
}

enum DhikrDisplayContentRegistry {
    static func content(for dhikr: Dhikr, language: AppLanguage) -> DhikrDisplayContent {
        guard !dhikr.isCustom else {
            return DhikrDisplayContent(title: dhikr.title, translation: dhikr.translation)
        }

        switch language {
        case .english:
            return DhikrDisplayContent(title: dhikr.title, translation: dhikr.translation)
        case .arabic:
            return dhikr.catalogKey
                .flatMap { contentLookupKeyByCatalogKey[$0] }
                .flatMap { arabic[$0] }
                ?? DhikrDisplayContent(title: dhikr.title, translation: dhikr.translation)
        case .malayalam:
            return dhikr.catalogKey
                .flatMap { contentLookupKeyByCatalogKey[$0] }
                .flatMap { malayalam[$0] }
                ?? DhikrDisplayContent(title: dhikr.title, translation: dhikr.translation)
        }
    }

    private static let contentLookupKeyByCatalogKey: [String: String] = [
        "surah-ikhlas": "qul huwa allahu ahad",
        "tahleel": "la ilaha illallah",
        "ya-wahhabu": "ya wahhabu",
        "isthighfar": "asthaghfirullahil azeem",
        "swalath-al-fathimiyya": "allahumma swalli ala nnoori wa ahlihi",
        "swalath": "swallallahu ala muhammad, swallallahu alayhi wa sallim",
        "swalath-sayyidina": "allahumma swalli ala sayyidina muhammadin wa ala aalihi wa swahbihi wa sallim",
        "swalath-al-fatih": "swalath al fatih",
        "swalath-al-nariyya": "swalath al nariyya",
        "swalath-for-debt": "allāhumma ṣalli ʿalā muḥammadin ʿabdika wa rasūlika wa ʿalā al-muʾminīna wa al-muslimīna wa lil-muʾmināti wa al-muslimāt.",
        "ramadan-dhikr": "ash'hadu an la ilaha illallahu, asthaghfirullah, as'alukal jannatha wa au'dhu bika mina nnaar",
        "ramadan-first-ten-nights": "allahummarhamni ya arhama rrahimin",
        "ramadan-second-ten-nights": "allahummaghfirli dhunubi ya rabbal aalameen",
    ]

    private static let arabic: [String: DhikrDisplayContent] = [
        "qul huwa allahu ahad": DhikrDisplayContent(
            title: "سورة الإخلاص",
            translation: "سورة الإخلاص"
        ),
        "la ilaha illallah": DhikrDisplayContent(
            title: "التهليل",
            translation: "لا إله إلا الله."
        ),
        "ya wahhabu": DhikrDisplayContent(
            title: "يا وهاب",
            translation: "يا كثير العطاء."
        ),
        "asthaghfirullahil azeem": DhikrDisplayContent(
            title: "الاستغفار",
            translation: "أستغفر الله العظيم."
        ),
        "allahumma swalli ala nnoori wa ahlihi": DhikrDisplayContent(
            title: "الصلاة الفاطمية",
            translation: "اللهم صل على النور وأهله."
        ),
        "swallallahu ala muhammad, swallallahu alayhi wa sallim": DhikrDisplayContent(
            title: "الصلاة على النبي",
            translation: "صلى الله على محمد، صلى الله عليه وسلم."
        ),
        "allahumma swalli ala sayyidina muhammadin wa ala aalihi wa swahbihi wa sallim": DhikrDisplayContent(
            title: "الصلاة على سيدنا محمد",
            translation: "اللهم صل وسلم على سيدنا محمد وآله وصحبه."
        ),
        "swalath al fatih": DhikrDisplayContent(
            title: "صلاة الفاتح",
            translation: "اللهم صل على سيدنا محمد الفاتح لما أغلق."
        ),
        "swalath al nariyya": DhikrDisplayContent(
            title: "الصلاة النارية",
            translation: "صلاة كاملة وسلام تام على سيدنا محمد."
        ),
        "allāhumma ṣalli ʿalā muḥammadin ʿabdika wa rasūlika wa ʿalā al-muʾminīna wa al-muslimīna wa lil-muʾmināti wa al-muslimāt.": DhikrDisplayContent(
            title: "صلاة قضاء الدين",
            translation: "اللهم صل على محمد عبدك ورسولك وعلى المؤمنين والمؤمنات."
        ),
        "ash'hadu an la ilaha illallahu, asthaghfirullah, as'alukal jannatha wa au'dhu bika mina nnaar": DhikrDisplayContent(
            title: "ذكر رمضان",
            translation: "أشهد أن لا إله إلا الله، أستغفر الله، أسألك الجنة وأعوذ بك من النار."
        ),
        "allahummarhamni ya arhama rrahimin": DhikrDisplayContent(
            title: "العشر الأوائل من رمضان",
            translation: "اللهم ارحمني يا أرحم الراحمين."
        ),
        "allahummaghfirli dhunubi ya rabbal aalameen": DhikrDisplayContent(
            title: "العشر الوسطى من رمضان",
            translation: "اللهم اغفر لي ذنوبي يا رب العالمين."
        )
    ]

    private static let malayalam: [String: DhikrDisplayContent] = [
        "qul huwa allahu ahad": DhikrDisplayContent(
            title: "സൂറത് അൽ ഇഖ്ലാസ്",
            translation: "സൂറത് അൽ ഇഖ്ലാസ്"
        ),
        "la ilaha illallah": DhikrDisplayContent(
            title: "തഹ്‌ലീൽ",
            translation: "അല്ലാഹുവല്ലാതെ ആരാധനയ്ക്ക് അർഹനില്ല."
        ),
        "ya wahhabu": DhikrDisplayContent(
            title: "യാ വഹ്ഹാബ്",
            translation: "അനുഗ്രഹങ്ങൾ ധാരാളമായി നൽകുന്നവനേ."
        ),
        "asthaghfirullahil azeem": DhikrDisplayContent(
            title: "ഇസ്തിഗ്ഫാർ",
            translation: "മഹത്തായ അല്ലാഹുവിനോട് ഞാൻ പാപമോചനം തേടുന്നു."
        ),
        "allahumma swalli ala nnoori wa ahlihi": DhikrDisplayContent(
            title: "സ്വലാത്ത് അൽ ഫാത്വിമിയ്യ",
            translation: "നൂറിനും അവിടുത്തെ കുടുംബത്തിനും സ്വലാത്ത് അയക്കണമേ."
        ),
        "swallallahu ala muhammad, swallallahu alayhi wa sallim": DhikrDisplayContent(
            title: "സ്വലാത്ത്",
            translation: "മുഹമ്മദ് നബിയിലേക്ക് അല്ലാഹുവിന്റെ അനുഗ്രഹവും സമാധാനവും ഉണ്ടാകട്ടെ."
        ),
        "allahumma swalli ala sayyidina muhammadin wa ala aalihi wa swahbihi wa sallim": DhikrDisplayContent(
            title: "സ്വലാത്ത് 2",
            translation: "സയ്യിദുനാ മുഹമ്മദ് നബിയുടെയും കുടുംബത്തിന്റെയും സഹാബികളുടെയും മേൽ സ്വലാത്തും സലാമും."
        ),
        "swalath al fatih": DhikrDisplayContent(
            title: "സ്വലാത്തുൽ ഫാത്തിഹ്",
            translation: "അടഞ്ഞതിനെ തുറന്ന സയ്യിദുനാ മുഹമ്മദ് നബിയിലേക്ക് സ്വലാത്ത്."
        ),
        "swalath al nariyya": DhikrDisplayContent(
            title: "സ്വലാത്തുന്നാരിയ്യ",
            translation: "സയ്യിദുനാ മുഹമ്മദ് നബിയിലേക്ക് സമ്പൂർണ സ്വലാത്തും സമാധാനവും."
        ),
        "allāhumma ṣalli ʿalā muḥammadin ʿabdika wa rasūlika wa ʿalā al-muʾminīna wa al-muslimīna wa lil-muʾmināti wa al-muslimāt.": DhikrDisplayContent(
            title: "കടം തീർക്കാനുള്ള സ്വലാത്ത്",
            translation: "അല്ലാഹുവേ, നിന്റെ ദാസനും ദൂതനുമായ മുഹമ്മദ് നബിയിലേക്കും വിശ്വാസികളിലേക്കും സ്വലാത്ത് അയക്കണമേ."
        ),
        "ash'hadu an la ilaha illallahu, asthaghfirullah, as'alukal jannatha wa au'dhu bika mina nnaar": DhikrDisplayContent(
            title: "റമദാൻ ദിക്ർ",
            translation: "അല്ലാഹുവല്ലാതെ ആരാധനയ്ക്ക് അർഹനില്ലെന്ന് ഞാൻ സാക്ഷ്യം വഹിക്കുന്നു; പാപമോചനം തേടുന്നു; സ്വർഗം ചോദിക്കുകയും നരകത്തിൽ നിന്ന് അഭയം തേടുകയും ചെയ്യുന്നു."
        ),
        "allahummarhamni ya arhama rrahimin": DhikrDisplayContent(
            title: "ആദ്യ പത്ത് രാത്രികൾ",
            translation: "അല്ലാഹുവേ, കാരുണ്യം കാണിക്കുന്നവരിൽ ഏറ്റവും കാരുണ്യമുള്ളവനേ, എന്നോട് കരുണ കാണിക്കണമേ."
        ),
        "allahummaghfirli dhunubi ya rabbal aalameen": DhikrDisplayContent(
            title: "രണ്ടാം പത്ത് രാത്രികൾ",
            translation: "അല്ലാഹുവേ, ലോകങ്ങളുടെ രക്ഷിതാവേ, എന്റെ പാപങ്ങൾ പൊറുത്തുതരണമേ."
        )
    ]
}

extension Dhikr {
    func displayTitle(language: AppLanguage) -> String {
        DhikrDisplayContentRegistry.content(for: self, language: language).title
    }

    func displayTranslation(language: AppLanguage) -> String {
        DhikrDisplayContentRegistry.content(for: self, language: language).translation
    }

    func localizedSearchText(language: AppLanguage) -> [String] {
        let content = DhikrDisplayContentRegistry.content(for: self, language: language)
        return [content.title, content.translation, title, transliteration, translation, arabic]
    }
}
