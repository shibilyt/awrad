import Foundation

struct DhikrBenefitDetail: Identifiable, Hashable {
    var id: String { [title, source ?? ""].joined(separator: "|") }
    var title: String
    var description: String
    var source: String?
}

struct DhikrSuggestedGoal: Identifiable, Hashable {
    var id: String {
        [
            label,
            String(targetCount),
            targetPolicy.rawValue,
            frequency.rawValue
        ].joined(separator: "|")
    }

    var label: String
    var description: String
    var targetCount: Int
    var frequency: RecurrenceFrequency = .daily
    var targetPolicy: TargetPolicy = .perDueDate
}

struct DhikrGuidance: Hashable {
    var benefits: [DhikrBenefitDetail]
    var suggestedGoals: [DhikrSuggestedGoal]

    func localized(language: AppLanguage) -> DhikrGuidance {
        guard language != .english else { return self }
        return DhikrGuidance(
            benefits: benefits.map { $0.localized(language: language) },
            suggestedGoals: suggestedGoals.map { $0.localized(language: language) }
        )
    }
}

enum DhikrGuidanceRegistry {
    static func guidance(for dhikr: Dhikr) -> DhikrGuidance {
        if let guidance = registry[dhikr.transliteration] {
            return guidance
        }

        let fallbackBenefits = dhikr.benefits.map {
            DhikrBenefitDetail(title: $0, description: $0, source: nil)
        }
        return DhikrGuidance(benefits: fallbackBenefits, suggestedGoals: [])
    }

    static func guidance(for dhikr: Dhikr, language: AppLanguage) -> DhikrGuidance {
        guidance(for: dhikr).localized(language: language)
    }

    private static let registry: [String: DhikrGuidance] = [
        "La ilaha illallah": DhikrGuidance(
            benefits: [
                DhikrBenefitDetail(
                    title: "Best of speech",
                    description: "The Prophet ﷺ said: \"The best of what I and the prophets before me have said is: La ilaha illallah.\"",
                    source: "Tirmidhi 3585"
                ),
                DhikrBenefitDetail(
                    title: "Key to Paradise",
                    description: "Whoever's last words are La ilaha illallah will enter Paradise.",
                    source: "Abu Dawud 3116"
                ),
                DhikrBenefitDetail(
                    title: "Heaviest on the scales",
                    description: "On the Day of Judgement, nothing will be heavier in the scales than La ilaha illallah.",
                    source: "Tirmidhi 3462"
                )
            ],
            suggestedGoals: [
                DhikrSuggestedGoal(
                    label: "Daily 100x",
                    description: "Recite 100 times daily for reward and protection.",
                    targetCount: 100
                ),
                DhikrSuggestedGoal(
                    label: "Daily 1,000x",
                    description: "A steady daily wird for closeness to Allah.",
                    targetCount: 1_000
                ),
                DhikrSuggestedGoal(
                    label: "One-time 70,000x",
                    description: "Complete 70,000 recitations as a long-form spiritual undertaking.",
                    targetCount: 70_000,
                    targetPolicy: .cumulativeTotal
                )
            ]
        ),
        "Ya Wahhabu": DhikrGuidance(
            benefits: [
                DhikrBenefitDetail(
                    title: "The Bestower of gifts",
                    description: "Al-Wahhab is one of Allah's beautiful names, invoking His generosity and boundless giving.",
                    source: nil
                ),
                DhikrBenefitDetail(
                    title: "Provision and sustenance",
                    description: "Reciting Ya Wahhabu is a devotional practice for seeking provision through Allah's grace.",
                    source: nil
                )
            ],
            suggestedGoals: [
                DhikrSuggestedGoal(
                    label: "Daily 100x",
                    description: "Daily recitation for seeking Allah's blessings and gifts.",
                    targetCount: 100
                ),
                DhikrSuggestedGoal(
                    label: "One-time 10,000x",
                    description: "A long-form total for a specific need or request.",
                    targetCount: 10_000,
                    targetPolicy: .cumulativeTotal
                )
            ]
        ),
        "Asthaghfirullahil Azeem": DhikrGuidance(
            benefits: [
                DhikrBenefitDetail(
                    title: "Relief from distress",
                    description: "Constant istighfar is connected with relief from worries and a way out from difficulty.",
                    source: "Abu Dawud 1518"
                ),
                DhikrBenefitDetail(
                    title: "Forgiveness of sins",
                    description: "Allah calls His servants to seek forgiveness from their Lord.",
                    source: "Quran 71:10"
                ),
                DhikrBenefitDetail(
                    title: "Increase in provision",
                    description: "Surah Nuh connects seeking forgiveness with increase in provision and blessings.",
                    source: "Quran 71:10-12"
                )
            ],
            suggestedGoals: [
                DhikrSuggestedGoal(
                    label: "Daily 100x",
                    description: "A daily istighfar practice aligned with prophetic habit.",
                    targetCount: 100
                ),
                DhikrSuggestedGoal(
                    label: "Daily 1,000x",
                    description: "An intensive daily istighfar for purification of the heart.",
                    targetCount: 1_000
                )
            ]
        ),
        "Allahumma swalli ala nnoori wa ahlihi": DhikrGuidance(
            benefits: [
                DhikrBenefitDetail(
                    title: "Swalath upon the Light",
                    description: "A blessed prayer upon the Prophet ﷺ associated with spiritual connection and reverence.",
                    source: nil
                ),
                DhikrBenefitDetail(
                    title: "Spiritual illumination",
                    description: "Sending blessings upon the Prophet ﷺ is a devotional means of bringing light into the heart.",
                    source: nil
                )
            ],
            suggestedGoals: [
                DhikrSuggestedGoal(
                    label: "Daily 100x",
                    description: "A regular daily recitation for spiritual connection.",
                    targetCount: 100
                ),
                DhikrSuggestedGoal(
                    label: "One-time 4,444x",
                    description: "Complete 4,444 recitations for a specific need.",
                    targetCount: 4_444,
                    targetPolicy: .cumulativeTotal
                )
            ]
        ),
        "Swallallahu ala Muhammad, swallallahu alayhi wa sallim": DhikrGuidance(
            benefits: [
                DhikrBenefitDetail(
                    title: "Ten blessings from Allah",
                    description: "Whoever sends blessings upon the Prophet ﷺ once receives tenfold blessings from Allah.",
                    source: "Muslim 408"
                ),
                DhikrBenefitDetail(
                    title: "Closeness to the Prophet ﷺ",
                    description: "Abundant blessings upon the Prophet ﷺ are connected with closeness to him on the Day of Judgement.",
                    source: "Tirmidhi 484"
                )
            ],
            suggestedGoals: [
                DhikrSuggestedGoal(
                    label: "Daily 100x",
                    description: "Daily swalath for blessings and closeness to the Prophet ﷺ.",
                    targetCount: 100
                ),
                DhikrSuggestedGoal(
                    label: "Daily 500x",
                    description: "A fuller daily swalath practice.",
                    targetCount: 500
                )
            ]
        ),
        "Allahumma swalli ala sayyidina Muhammadin wa ala aalihi wa swahbihi wa sallim": DhikrGuidance(
            benefits: [
                DhikrBenefitDetail(
                    title: "Complete swalath",
                    description: "This comprehensive wording includes blessings upon the Prophet ﷺ, his family, and his companions.",
                    source: nil
                ),
                DhikrBenefitDetail(
                    title: "Friday excellence",
                    description: "The Prophet ﷺ encouraged abundant blessings upon him on Friday.",
                    source: "Abu Dawud 1047"
                )
            ],
            suggestedGoals: [
                DhikrSuggestedGoal(
                    label: "Daily 100x",
                    description: "A daily practice of complete swalath.",
                    targetCount: 100
                ),
                DhikrSuggestedGoal(
                    label: "One-time 10,000x",
                    description: "A grand completion for immense spiritual reward.",
                    targetCount: 10_000,
                    targetPolicy: .cumulativeTotal
                )
            ]
        ),
        "Swalath al Fatih": DhikrGuidance(
            benefits: [
                DhikrBenefitDetail(
                    title: "The Opening Prayer",
                    description: "Swalath al Fatih is known as a prayer that opens what is closed and seals what has preceded.",
                    source: nil
                ),
                DhikrBenefitDetail(
                    title: "Guidance to the straight path",
                    description: "It describes the Prophet ﷺ as the guide to Allah's straight path.",
                    source: nil
                )
            ],
            suggestedGoals: [
                DhikrSuggestedGoal(
                    label: "Daily 11x",
                    description: "A compact daily recitation.",
                    targetCount: 11
                ),
                DhikrSuggestedGoal(
                    label: "Daily 100x",
                    description: "Abundant daily recitation for those seeking its blessings.",
                    targetCount: 100
                ),
                DhikrSuggestedGoal(
                    label: "One-time 4,444x",
                    description: "Complete 4,444 recitations for a specific need.",
                    targetCount: 4_444,
                    targetPolicy: .cumulativeTotal
                )
            ]
        ),
        "Swalath al Nariyya": DhikrGuidance(
            benefits: [
                DhikrBenefitDetail(
                    title: "Relief from difficulties",
                    description: "Swalath al Nariyya is renowned as a devotional prayer for removing obstacles and difficulty.",
                    source: nil
                ),
                DhikrBenefitDetail(
                    title: "Fulfillment of needs",
                    description: "Its wording mentions knots being untied, worries relieved, and needs fulfilled.",
                    source: nil
                )
            ],
            suggestedGoals: [
                DhikrSuggestedGoal(
                    label: "Daily 11x",
                    description: "Daily recitation for removing obstacles.",
                    targetCount: 11
                ),
                DhikrSuggestedGoal(
                    label: "One-time 4,444x",
                    description: "A renowned completion for a pressing need.",
                    targetCount: 4_444,
                    targetPolicy: .cumulativeTotal
                ),
                DhikrSuggestedGoal(
                    label: "One-time 11,111x",
                    description: "A larger completion for serious needs.",
                    targetCount: 11_111,
                    targetPolicy: .cumulativeTotal
                )
            ]
        ),
        "Allāhumma ṣalli ʿalā Muḥammadin ʿabdika wa rasūlika wa ʿalā al-muʾminīna wa al-muslimīna wa lil-muʾmināti wa al-muslimāt.": DhikrGuidance(
            benefits: [],
            suggestedGoals: [
                DhikrSuggestedGoal(
                    label: "Daily 33x",
                    description: "Recite 33 times daily to seek relief from debt through the Prophet's ﷺ intercession.",
                    targetCount: 33
                ),
                DhikrSuggestedGoal(
                    label: "Daily 360x",
                    description: "Recite 360 times daily for urgent debt relief.",
                    targetCount: 360
                )
            ]
        ),
        "Ash'hadu an la ilaha illallahu, asthaghfirullah, as'alukal jannatha wa au'dhu bika mina nnaar": DhikrGuidance(
            benefits: [
                DhikrBenefitDetail(
                    title: "Comprehensive Ramadan dhikr",
                    description: "This combines testimony of faith, seeking forgiveness, asking for Paradise, and seeking refuge from the Fire.",
                    source: nil
                ),
                DhikrBenefitDetail(
                    title: "Gates of Paradise",
                    description: "Asking for Paradise and seeking refuge from the Fire are beloved supplications, especially in Ramadan.",
                    source: nil
                )
            ],
            suggestedGoals: [
                DhikrSuggestedGoal(
                    label: "Daily 100x",
                    description: "A daily practice throughout Ramadan.",
                    targetCount: 100
                )
            ]
        ),
        "Allahummarhamni ya arhama rrahimin": DhikrGuidance(
            benefits: [
                DhikrBenefitDetail(
                    title: "Seeking divine mercy",
                    description: "The first ten days of Ramadan are associated with mercy, and this dhikr invokes Allah's mercy directly.",
                    source: nil
                )
            ],
            suggestedGoals: [
                DhikrSuggestedGoal(
                    label: "Daily 100x",
                    description: "Recite daily during the first ten days of Ramadan.",
                    targetCount: 100
                )
            ]
        ),
        "Allahummaghfirli dhunubi ya rabbal aalameen": DhikrGuidance(
            benefits: [
                DhikrBenefitDetail(
                    title: "Seeking forgiveness in Ramadan",
                    description: "The second ten days of Ramadan are associated with forgiveness.",
                    source: nil
                )
            ],
            suggestedGoals: [
                DhikrSuggestedGoal(
                    label: "Daily 100x",
                    description: "Recite daily during the second ten days of Ramadan.",
                    targetCount: 100
                )
            ]
        )
    ]
}

private extension DhikrBenefitDetail {
    func localized(language: AppLanguage) -> DhikrBenefitDetail {
        let content = DhikrGuidanceLocalization.benefitContent(for: self, language: language)
        return DhikrBenefitDetail(title: content.title, description: content.description, source: source)
    }
}

private extension DhikrSuggestedGoal {
    func localized(language: AppLanguage) -> DhikrSuggestedGoal {
        DhikrSuggestedGoal(
            label: DhikrGuidanceLocalization.suggestedGoalLabel(for: self, language: language),
            description: DhikrGuidanceLocalization.suggestedGoalDescription(for: self, language: language),
            targetCount: targetCount,
            frequency: frequency,
            targetPolicy: targetPolicy
        )
    }
}

private enum DhikrGuidanceLocalization {
    static func benefitContent(for benefit: DhikrBenefitDetail, language: AppLanguage) -> DhikrBenefitDetail {
        switch language {
        case .english:
            return benefit
        case .arabic:
            return arabicBenefits[benefit.id] ?? benefit
        case .malayalam:
            return malayalamBenefits[benefit.id] ?? benefit
        }
    }

    static func suggestedGoalLabel(for suggestion: DhikrSuggestedGoal, language: AppLanguage) -> String {
        guard language != .english else { return suggestion.label }
        let count = formattedCount(suggestion.targetCount, language: language)
        switch language {
        case .english:
            return suggestion.label
        case .arabic:
            return suggestion.targetPolicy == .cumulativeTotal ? "إكمال \(count) مرة" : "يوميًا \(count) مرة"
        case .malayalam:
            return suggestion.targetPolicy == .cumulativeTotal ? "\(count) പൂർത്തിയാക്കുക" : "ദൈനംദിനം \(count)"
        }
    }

    static func suggestedGoalDescription(for suggestion: DhikrSuggestedGoal, language: AppLanguage) -> String {
        guard language != .english else { return suggestion.description }
        let count = formattedCount(suggestion.targetCount, language: language)
        switch language {
        case .english:
            return suggestion.description
        case .arabic:
            if suggestion.targetPolicy == .cumulativeTotal {
                return "أكمل \(count) تكرارًا كختمة مركزة لهذا الذكر."
            }
            return "اجعل هذا وردًا يوميًا بعدد \(count) تكرار."
        case .malayalam:
            if suggestion.targetPolicy == .cumulativeTotal {
                return "\(count) ആവർത്തനങ്ങൾ ഒരു കേന്ദ്രീകൃത സമാപനമായി പൂർത്തിയാക്കുക."
            }
            return "\(count) ആവർത്തനങ്ങളുള്ള ദൈനംദിന വിർദ് ആക്കുക."
        }
    }

    private static func formattedCount(_ count: Int, language: AppLanguage) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }

    private static let arabicBenefits: [String: DhikrBenefitDetail] = [
        "Recited for protection, focus, and remembrance.|": DhikrBenefitDetail(
            title: "للحفظ والذكر",
            description: "تُقرأ سورة الإخلاص للتوحيد والحفظ وتجديد حضور القلب.",
            source: nil
        ),
        "Best of speech|Tirmidhi 3585": DhikrBenefitDetail(
            title: "أفضل الذكر",
            description: "بيّن النبي ﷺ أن من أفضل ما قاله الأنبياء كلمة: لا إله إلا الله.",
            source: "Tirmidhi 3585"
        ),
        "Key to Paradise|Abu Dawud 3116": DhikrBenefitDetail(
            title: "مفتاح الجنة",
            description: "من كان آخر كلامه لا إله إلا الله دخل الجنة.",
            source: "Abu Dawud 3116"
        ),
        "Heaviest on the scales|Tirmidhi 3462": DhikrBenefitDetail(
            title: "ثقيلة في الميزان",
            description: "هذه الكلمة العظيمة من أثقل الأذكار في الميزان يوم القيامة.",
            source: "Tirmidhi 3462"
        ),
        "The Bestower of gifts|": DhikrBenefitDetail(
            title: "الوهاب",
            description: "الوهاب من أسماء الله الحسنى، وفيه استحضار لجوده وعطائه الواسع.",
            source: nil
        ),
        "Provision and sustenance|": DhikrBenefitDetail(
            title: "الرزق والعطاء",
            description: "نداء يا وهاب ممارسة تعبدية في طلب الرزق والفضل من الله.",
            source: nil
        ),
        "Relief from distress|Abu Dawud 1518": DhikrBenefitDetail(
            title: "تفريج الكرب",
            description: "المداومة على الاستغفار مرتبطة بتفريج الهموم وفتح المخارج من الشدة.",
            source: "Abu Dawud 1518"
        ),
        "Forgiveness of sins|Quran 71:10": DhikrBenefitDetail(
            title: "مغفرة الذنوب",
            description: "يدعو الله عباده إلى الاستغفار والرجوع إليه.",
            source: "Quran 71:10"
        ),
        "Increase in provision|Quran 71:10-12": DhikrBenefitDetail(
            title: "زيادة الرزق",
            description: "تربط سورة نوح بين الاستغفار ونزول البركات وزيادة الرزق.",
            source: "Quran 71:10-12"
        ),
        "Swalath upon the Light|": DhikrBenefitDetail(
            title: "الصلاة على النور",
            description: "صيغة مباركة في الصلاة على النبي ﷺ، وفيها تعظيم ومحبة.",
            source: nil
        ),
        "Spiritual illumination|": DhikrBenefitDetail(
            title: "نور القلب",
            description: "الصلاة على النبي ﷺ باب تعبدي لجلب النور إلى القلب.",
            source: nil
        ),
        "Ten blessings from Allah|Muslim 408": DhikrBenefitDetail(
            title: "عشر صلوات من الله",
            description: "من صلى على النبي ﷺ مرة صلى الله عليه بها عشرًا.",
            source: "Muslim 408"
        ),
        "Closeness to the Prophet ﷺ|Tirmidhi 484": DhikrBenefitDetail(
            title: "القرب من النبي ﷺ",
            description: "الإكثار من الصلاة على النبي ﷺ سبب للقرب منه يوم القيامة.",
            source: "Tirmidhi 484"
        ),
        "Complete swalath|": DhikrBenefitDetail(
            title: "صيغة جامعة",
            description: "تجمع هذه الصيغة الصلاة على النبي ﷺ وآله وصحبه.",
            source: nil
        ),
        "Friday excellence|Abu Dawud 1047": DhikrBenefitDetail(
            title: "فضل يوم الجمعة",
            description: "حث النبي ﷺ على الإكثار من الصلاة عليه يوم الجمعة.",
            source: "Abu Dawud 1047"
        ),
        "The Opening Prayer|": DhikrBenefitDetail(
            title: "صلاة الفاتح",
            description: "تُعرف صلاة الفاتح بأنها تفتح ما أغلق وتختم ما سبق.",
            source: nil
        ),
        "Guidance to the straight path|": DhikrBenefitDetail(
            title: "الهداية للصراط المستقيم",
            description: "تصف النبي ﷺ بأنه الهادي إلى صراط الله المستقيم.",
            source: nil
        ),
        "Relief from difficulties|": DhikrBenefitDetail(
            title: "تفريج الشدائد",
            description: "اشتهرت الصلاة النارية كورد لرفع العوائق والشدائد.",
            source: nil
        ),
        "Fulfillment of needs|": DhikrBenefitDetail(
            title: "قضاء الحوائج",
            description: "تذكر صيغتها انحلال العقد وتفريج الكرب وقضاء الحوائج.",
            source: nil
        ),
        "Comprehensive Ramadan dhikr|": DhikrBenefitDetail(
            title: "ذكر جامع في رمضان",
            description: "يجمع بين الشهادة والاستغفار وسؤال الجنة والاستعاذة من النار.",
            source: nil
        ),
        "Gates of Paradise|": DhikrBenefitDetail(
            title: "سؤال الجنة",
            description: "سؤال الجنة والاستعاذة من النار من الدعاء المحبوب، وخاصة في رمضان.",
            source: nil
        ),
        "Seeking divine mercy|": DhikrBenefitDetail(
            title: "طلب الرحمة",
            description: "يرتبط أول رمضان بالرحمة، وهذا الذكر يتوجه إلى الله بطلبها مباشرة.",
            source: nil
        ),
        "Seeking forgiveness in Ramadan|": DhikrBenefitDetail(
            title: "طلب المغفرة في رمضان",
            description: "ترتبط العشر الوسطى من رمضان بالمغفرة والرجوع إلى الله.",
            source: nil
        )
    ]

    private static let malayalamBenefits: [String: DhikrBenefitDetail] = [
        "Recited for protection, focus, and remembrance.|": DhikrBenefitDetail(
            title: "സംരക്ഷണവും സ്മരണയും",
            description: "തൗഹീദ് ഉറപ്പിക്കാനും ഹൃദയം സ്മരണയിൽ നിലനിർത്താനും സൂറത് ഇഖ്ലാസ് വായിക്കുന്നു.",
            source: nil
        ),
        "Best of speech|Tirmidhi 3585": DhikrBenefitDetail(
            title: "മികച്ച ദിക്ർ",
            description: "മുൻ പ്രവാചകന്മാരും താനും പറഞ്ഞതിൽ ഏറ്റവും ഉത്തമമായത് ലാ ഇലാഹ ഇല്ലല്ലാഹ് ആണെന്ന് നബി ﷺ അറിയിച്ചു.",
            source: "Tirmidhi 3585"
        ),
        "Key to Paradise|Abu Dawud 3116": DhikrBenefitDetail(
            title: "സ്വർഗത്തിന്റെ താക്കോൽ",
            description: "അവസാന വാക്കുകൾ ലാ ഇലാഹ ഇല്ലല്ലാഹ് ആയവൻ സ്വർഗത്തിൽ പ്രവേശിക്കും.",
            source: "Abu Dawud 3116"
        ),
        "Heaviest on the scales|Tirmidhi 3462": DhikrBenefitDetail(
            title: "തുലാസിൽ ഭാരമുള്ളത്",
            description: "ഖിയാമത്ത് നാളിൽ ഈ മഹത്തായ വാക്ക് തുലാസിൽ ഭാരമുള്ള ദിക്റുകളിൽ ഒന്നാണ്.",
            source: "Tirmidhi 3462"
        ),
        "The Bestower of gifts|": DhikrBenefitDetail(
            title: "അൽ വഹ്ഹാബ്",
            description: "അല്ലാഹുവിന്റെ മനോഹര നാമങ്ങളിൽ ഒന്നാണ് അൽ വഹ്ഹാബ്; അവന്റെ വിശാലമായ ദാനവും കാരുണ്യവും ഓർമ്മിപ്പിക്കുന്നു.",
            source: nil
        ),
        "Provision and sustenance|": DhikrBenefitDetail(
            title: "റിസ്ഖും അനുഗ്രഹവും",
            description: "യാ വഹ്ഹാബ് എന്ന ദിക്ർ അല്ലാഹുവിന്റെ അനുഗ്രഹവും ഉപജീവനവും തേടുന്ന ആരാധനയാണ്.",
            source: nil
        ),
        "Relief from distress|Abu Dawud 1518": DhikrBenefitDetail(
            title: "കഷ്ടതയിൽ നിന്ന് ആശ്വാസം",
            description: "ഇസ്തിഗ്ഫാറിൽ സ്ഥിരത പുലർത്തുന്നത് വിഷമങ്ങളിൽ നിന്ന് ആശ്വാസവും ബുദ്ധിമുട്ടുകളിൽ നിന്ന് വഴിയും നൽകുന്നതുമായി ബന്ധപ്പെട്ടിരിക്കുന്നു.",
            source: "Abu Dawud 1518"
        ),
        "Forgiveness of sins|Quran 71:10": DhikrBenefitDetail(
            title: "പാപമോചനം",
            description: "അല്ലാഹു തന്റെ ദാസന്മാരെ രക്ഷിതാവിനോട് പാപമോചനം തേടാൻ വിളിക്കുന്നു.",
            source: "Quran 71:10"
        ),
        "Increase in provision|Quran 71:10-12": DhikrBenefitDetail(
            title: "ഉപജീവനത്തിലെ വർധന",
            description: "സൂറത് നൂഹ് ഇസ്തിഗ്ഫാറിനെ അനുഗ്രഹങ്ങളും ഉപജീവനവും വർധിക്കുന്നതുമായി ബന്ധിപ്പിക്കുന്നു.",
            source: "Quran 71:10-12"
        ),
        "Swalath upon the Light|": DhikrBenefitDetail(
            title: "നൂറിന്മേൽ സ്വലാത്ത്",
            description: "നബി ﷺയിലേക്കുള്ള സ്നേഹവും ആദരവും നിറഞ്ഞ അനുഗ്രഹീത സ്വലാത്ത്.",
            source: nil
        ),
        "Spiritual illumination|": DhikrBenefitDetail(
            title: "ഹൃദയത്തിന്റെ പ്രകാശം",
            description: "നബി ﷺയിലേക്ക് സ്വലാത്ത് ചൊല്ലുന്നത് ഹൃദയത്തിൽ പ്രകാശം വരുത്തുന്ന ആരാധനാ മാർഗമാണ്.",
            source: nil
        ),
        "Ten blessings from Allah|Muslim 408": DhikrBenefitDetail(
            title: "അല്ലാഹുവിൽ നിന്ന് പത്ത് അനുഗ്രഹങ്ങൾ",
            description: "നബി ﷺയിലേക്ക് ഒരിക്കൽ സ്വലാത്ത് ചൊല്ലുന്നവനോട് അല്ലാഹു പത്ത് അനുഗ്രഹങ്ങൾ നൽകും.",
            source: "Muslim 408"
        ),
        "Closeness to the Prophet ﷺ|Tirmidhi 484": DhikrBenefitDetail(
            title: "നബി ﷺയോട് അടുത്ത്",
            description: "നബി ﷺയിലേക്ക് ധാരാളം സ്വലാത്ത് ചൊല്ലുന്നത് ഖിയാമത്ത് നാളിൽ അവിടുത്തോട് അടുത്തിരിക്കാൻ കാരണമാകുന്നു.",
            source: "Tirmidhi 484"
        ),
        "Complete swalath|": DhikrBenefitDetail(
            title: "സമഗ്ര സ്വലാത്ത്",
            description: "നബി ﷺ, അവിടുത്തെ കുടുംബം, സഹാബികൾ എന്നിവർക്കുള്ള അനുഗ്രഹം ഈ വാചകത്തിൽ ഒന്നിക്കുന്നു.",
            source: nil
        ),
        "Friday excellence|Abu Dawud 1047": DhikrBenefitDetail(
            title: "വെള്ളിയാഴ്ചയുടെ ശ്രേഷ്ഠത",
            description: "വെള്ളിയാഴ്ച നബി ﷺയിലേക്ക് കൂടുതൽ സ്വലാത്ത് ചൊല്ലാൻ പ്രോത്സാഹനം ഉണ്ട്.",
            source: "Abu Dawud 1047"
        ),
        "The Opening Prayer|": DhikrBenefitDetail(
            title: "സ്വലാത്തുൽ ഫാത്തിഹ്",
            description: "അടഞ്ഞതിനെ തുറക്കുന്നതും മുമ്പുണ്ടായതിനെ മുദ്രവെയ്ക്കുന്നതുമായ സ്വലാത്തായി ഇത് അറിയപ്പെടുന്നു.",
            source: nil
        ),
        "Guidance to the straight path|": DhikrBenefitDetail(
            title: "നേരായ പാതയിലേക്കുള്ള മാർഗദർശനം",
            description: "നബി ﷺയെ അല്ലാഹുവിന്റെ നേരായ പാതയിലേക്ക് നയിക്കുന്നവനായി ഇത് വിശേഷിപ്പിക്കുന്നു.",
            source: nil
        ),
        "Relief from difficulties|": DhikrBenefitDetail(
            title: "കഷ്ടതകളിൽ നിന്ന് ആശ്വാസം",
            description: "തടസ്സങ്ങളും ബുദ്ധിമുട്ടുകളും മാറാൻ വായിക്കുന്ന സ്വലാത്തായി സ്വലാത്തുന്നാരിയ്യ പ്രസിദ്ധമാണ്.",
            source: nil
        ),
        "Fulfillment of needs|": DhikrBenefitDetail(
            title: "ആവശ്യങ്ങൾ നിറവേറൽ",
            description: "കെട്ടുകൾ അഴിയുകയും വിഷമങ്ങൾ മാറുകയും ആവശ്യങ്ങൾ നിറവേറുകയും ചെയ്യുന്നതിനെ അതിന്റെ വാചകം സൂചിപ്പിക്കുന്നു.",
            source: nil
        ),
        "Comprehensive Ramadan dhikr|": DhikrBenefitDetail(
            title: "സമഗ്ര റമദാൻ ദിക്ർ",
            description: "ശഹാദത്ത്, ഇസ്തിഗ്ഫാർ, സ്വർഗം ചോദിക്കൽ, നരകത്തിൽ നിന്ന് അഭയം തേടൽ എന്നിവ ഇതിൽ ഒന്നിക്കുന്നു.",
            source: nil
        ),
        "Gates of Paradise|": DhikrBenefitDetail(
            title: "സ്വർഗം ചോദിക്കൽ",
            description: "സ്വർഗം ചോദിക്കുകയും നരകത്തിൽ നിന്ന് അഭയം തേടുകയും ചെയ്യുന്നത് പ്രത്യേകിച്ച് റമദാനിൽ പ്രിയപ്പെട്ട ദുആകളാണ്.",
            source: nil
        ),
        "Seeking divine mercy|": DhikrBenefitDetail(
            title: "ദൈവിക കരുണ തേടൽ",
            description: "റമദാനിലെ ആദ്യ പത്ത് ദിവസങ്ങൾ കരുണയുമായി ബന്ധപ്പെട്ടതാണ്; ഈ ദിക്ർ ആ കരുണ നേരിട്ട് തേടുന്നു.",
            source: nil
        ),
        "Seeking forgiveness in Ramadan|": DhikrBenefitDetail(
            title: "റമദാനിൽ പാപമോചനം തേടൽ",
            description: "റമദാനിലെ രണ്ടാം പത്ത് ദിവസങ്ങൾ പാപമോചനത്തോടും അല്ലാഹുവിലേക്കുള്ള മടക്കത്തോടും ബന്ധപ്പെട്ടതാണ്.",
            source: nil
        )
    ]
}
