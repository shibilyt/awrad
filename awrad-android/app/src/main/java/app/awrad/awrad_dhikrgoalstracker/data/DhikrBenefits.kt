package app.awrad.awrad_dhikrgoalstracker.data

import app.awrad.awrad_dhikrgoalstracker.data.model.FrequencyType

data class DhikrBenefit(
    val title: String,
    val description: String,
    val source: String? = null,
)

data class SuggestedGoal(
    val label: String,
    val description: String,
    val targetCount: Int,
    val frequencyType: FrequencyType = FrequencyType.DAILY,
    val isOneTime: Boolean = false,
)

data class DhikrBenefitsData(
    val benefits: List<DhikrBenefit>,
    val suggestedGoals: List<SuggestedGoal>,
)

object DhikrBenefitsRegistry {

    fun getBenefits(transliteration: String): DhikrBenefitsData? =
        registry[transliteration]

    private val registry: Map<String, DhikrBenefitsData> = mapOf(
        // PRAISE
        "La ilaha illallah" to DhikrBenefitsData(
            benefits = listOf(
                DhikrBenefit(
                    title = "Best of speech",
                    description = "The Prophet ﷺ said: \"The best of what I and the prophets before me have said is: La ilaha illallah.\"",
                    source = "Tirmidhi 3585",
                ),
                DhikrBenefit(
                    title = "Key to Paradise",
                    description = "Whoever's last words are La ilaha illallah will enter Paradise.",
                    source = "Abu Dawud 3116",
                ),
                DhikrBenefit(
                    title = "Heaviest on the scales",
                    description = "On the Day of Judgement, nothing will be heavier in the scales than La ilaha illallah.",
                    source = "Tirmidhi 3462",
                ),
            ),
            suggestedGoals = listOf(
                SuggestedGoal(
                    label = "Daily 100x",
                    description = "Recite 100 times daily for immense reward and protection",
                    targetCount = 100,
                    frequencyType = FrequencyType.DAILY,
                ),
                SuggestedGoal(
                    label = "Daily 1,000x",
                    description = "A powerful daily wird for those seeking closeness to Allah",
                    targetCount = 1000,
                    frequencyType = FrequencyType.DAILY,
                ),
                SuggestedGoal(
                    label = "One-time 70,000x",
                    description = "Complete 70,000 recitations as a grand spiritual undertaking",
                    targetCount = 70000,
                    frequencyType = FrequencyType.DAILY,
                    isOneTime = true,
                ),
            ),
        ),

        "Ya Wahhabu" to DhikrBenefitsData(
            benefits = listOf(
                DhikrBenefit(
                    title = "The Bestower of gifts",
                    description = "Al-Wahhab is one of Allah's beautiful names meaning The Bestower. Calling upon this name invokes Allah's generosity and boundless giving.",
                ),
                DhikrBenefit(
                    title = "Provision and sustenance",
                    description = "Reciting Ya Wahhab opens doors of provision and removes financial difficulties through Allah's grace.",
                ),
            ),
            suggestedGoals = listOf(
                SuggestedGoal(
                    label = "Daily 100x",
                    description = "Daily recitation for seeking Allah's blessings and gifts",
                    targetCount = 100,
                    frequencyType = FrequencyType.DAILY,
                ),
                SuggestedGoal(
                    label = "One-time 10,000x",
                    description = "Grand total for a specific need or request from Allah",
                    targetCount = 10000,
                    frequencyType = FrequencyType.DAILY,
                    isOneTime = true,
                ),
            ),
        ),

        // FORGIVENESS
        "Asthaghfirullahil Azeem" to DhikrBenefitsData(
            benefits = listOf(
                DhikrBenefit(
                    title = "Relief from distress",
                    description = "The Prophet ﷺ said: \"Whoever makes istighfar constantly, Allah will give him relief from every worry and a way out from every difficulty.\"",
                    source = "Abu Dawud 1518",
                ),
                DhikrBenefit(
                    title = "Forgiveness of sins",
                    description = "Allah says: \"Ask forgiveness of your Lord. Indeed, He is ever a Perpetual Forgiver.\"",
                    source = "Quran 71:10",
                ),
                DhikrBenefit(
                    title = "Increase in provision",
                    description = "Istighfar brings increase in wealth, children, gardens, and rivers as mentioned in Surah Nuh.",
                    source = "Quran 71:10-12",
                ),
            ),
            suggestedGoals = listOf(
                SuggestedGoal(
                    label = "Daily 100x",
                    description = "The Prophet ﷺ used to seek forgiveness more than 100 times a day",
                    targetCount = 100,
                    frequencyType = FrequencyType.DAILY,
                ),
                SuggestedGoal(
                    label = "Daily 1,000x",
                    description = "Intensive daily istighfar for purification of the heart",
                    targetCount = 1000,
                    frequencyType = FrequencyType.DAILY,
                ),
            ),
        ),

        // SWALATHS
        "Allahumma swalli ala nnoori wa ahlihi" to DhikrBenefitsData(
            benefits = listOf(
                DhikrBenefit(
                    title = "Swalath upon the Light",
                    description = "Swalath Al Fathimiyya is a blessed prayer upon the Prophet ﷺ attributed to Sayyida Fatima Az-Zahra. It carries immense spiritual blessings.",
                ),
                DhikrBenefit(
                    title = "Spiritual illumination",
                    description = "Sending blessings upon the Noor (Light) of the Prophet ﷺ brings divine light into the heart of the reciter.",
                ),
            ),
            suggestedGoals = listOf(
                SuggestedGoal(
                    label = "Daily 100x",
                    description = "Regular daily recitation for spiritual connection",
                    targetCount = 100,
                    frequencyType = FrequencyType.DAILY,
                ),
                SuggestedGoal(
                    label = "One-time 4,444x",
                    description = "Complete 4,444 recitations for fulfillment of a specific need",
                    targetCount = 4444,
                    frequencyType = FrequencyType.DAILY,
                    isOneTime = true,
                ),
            ),
        ),

        "Swallallahu ala Muhammad, swallallahu alayhi wa sallim" to DhikrBenefitsData(
            benefits = listOf(
                DhikrBenefit(
                    title = "Ten blessings from Allah",
                    description = "The Prophet ﷺ said: \"Whoever sends blessings upon me once, Allah will send blessings upon him tenfold.\"",
                    source = "Muslim 408",
                ),
                DhikrBenefit(
                    title = "Closeness to the Prophet ﷺ",
                    description = "The closest people to the Prophet ﷺ on the Day of Judgement will be those who sent the most blessings upon him.",
                    source = "Tirmidhi 484",
                ),
            ),
            suggestedGoals = listOf(
                SuggestedGoal(
                    label = "Daily 100x",
                    description = "Daily swalath for blessings and closeness to the Prophet ﷺ",
                    targetCount = 100,
                    frequencyType = FrequencyType.DAILY,
                ),
                SuggestedGoal(
                    label = "Daily 500x",
                    description = "Abundant daily swalath as practiced by the righteous",
                    targetCount = 500,
                    frequencyType = FrequencyType.DAILY,
                ),
            ),
        ),

        "Allahumma swalli ala sayyidina Muhammadin wa ala aalihi wa swahbihi wa sallim" to DhikrBenefitsData(
            benefits = listOf(
                DhikrBenefit(
                    title = "Complete swalath",
                    description = "This comprehensive swalath includes blessings upon the Prophet ﷺ, his family, and his companions — covering the full scope of blessed souls.",
                ),
                DhikrBenefit(
                    title = "Friday excellence",
                    description = "The Prophet ﷺ said: \"Send abundant blessings upon me on Friday, for your blessings are presented to me.\"",
                    source = "Abu Dawud 1047",
                ),
            ),
            suggestedGoals = listOf(
                SuggestedGoal(
                    label = "Daily 100x",
                    description = "Daily practice of complete swalath",
                    targetCount = 100,
                    frequencyType = FrequencyType.DAILY,
                ),
                SuggestedGoal(
                    label = "One-time 10,000x",
                    description = "Grand completion for immense spiritual reward",
                    targetCount = 10000,
                    frequencyType = FrequencyType.DAILY,
                    isOneTime = true,
                ),
            ),
        ),

        "Swalath al Fatih" to DhikrBenefitsData(
            benefits = listOf(
                DhikrBenefit(
                    title = "The Opening Prayer",
                    description = "Swalath al Fatih is known as the prayer that opens what is closed and seals what has preceded. It is considered one of the most powerful swalaths.",
                ),
                DhikrBenefit(
                    title = "Immense reward",
                    description = "Scholars have mentioned that a single recitation of Swalath al Fatih is equivalent to 600,000 other swalaths in reward.",
                ),
                DhikrBenefit(
                    title = "Guidance to the straight path",
                    description = "It describes the Prophet ﷺ as the guide to Allah's straight path, and reciting it connects the heart to divine guidance.",
                ),
            ),
            suggestedGoals = listOf(
                SuggestedGoal(
                    label = "Daily 11x",
                    description = "Daily recitation as a powerful spiritual practice",
                    targetCount = 11,
                    frequencyType = FrequencyType.DAILY,
                ),
                SuggestedGoal(
                    label = "Daily 100x",
                    description = "Abundant daily recitation for those seeking its full blessings",
                    targetCount = 100,
                    frequencyType = FrequencyType.DAILY,
                ),
                SuggestedGoal(
                    label = "One-time 4,444x",
                    description = "Complete 4,444 recitations for fulfillment of a need",
                    targetCount = 4444,
                    frequencyType = FrequencyType.DAILY,
                    isOneTime = true,
                ),
            ),
        ),

        "Swalath al Nariyya" to DhikrBenefitsData(
            benefits = listOf(
                DhikrBenefit(
                    title = "Burns away difficulties",
                    description = "Known as the Fiery Prayer, Swalath al Nariyya is renowned for burning away obstacles and difficulties through its blessed recitation.",
                ),
                DhikrBenefit(
                    title = "Fulfillment of needs",
                    description = "It is described as the prayer through which knots are untied, worries are relieved, needs are fulfilled, and good endings are attained.",
                ),
                DhikrBenefit(
                    title = "Rain and blessings",
                    description = "The prayer mentions that rain is sought through the noble face of the Prophet ﷺ, indicating its connection to divine mercy.",
                ),
            ),
            suggestedGoals = listOf(
                SuggestedGoal(
                    label = "Daily 11x",
                    description = "Daily recitation for removing obstacles",
                    targetCount = 11,
                    frequencyType = FrequencyType.DAILY,
                ),
                SuggestedGoal(
                    label = "One-time 4,444x",
                    description = "The renowned practice of reciting 4,444 times for a pressing need",
                    targetCount = 4444,
                    frequencyType = FrequencyType.DAILY,
                    isOneTime = true,
                ),
                SuggestedGoal(
                    label = "One-time 11,111x",
                    description = "Grand completion for the most serious of needs",
                    targetCount = 11111,
                    frequencyType = FrequencyType.DAILY,
                    isOneTime = true,
                ),
            ),
        ),

        "Allāhumma ṣalli ʿalā Muḥammadin ʿabdika wa rasūlika wa ʿalā al-muʾminīna wa al-muslimīna wa lil-muʾmināti wa al-muslimāt." to DhikrBenefitsData(
            benefits = listOf(),
            suggestedGoals = listOf(
                SuggestedGoal(
                    label = "Daily 33x",
                    description = "Recite 33 times daily to seek relief from debt through the Prophet's ﷺ intercession",
                    targetCount = 33,
                    frequencyType = FrequencyType.DAILY,
                ),
                SuggestedGoal(
                    label = "Daily 360x",
                    description = "Recite 360 times daily for urgent debt relief when in dire need",
                    targetCount = 360,
                    frequencyType = FrequencyType.DAILY,
                ),
            ),
        ),

        // RAMADAN
        "Ash'hadu an la ilaha illallahu, asthaghfirullah, as'alukal jannatha wa au'dhu bika mina nnaar" to DhikrBenefitsData(
            benefits = listOf(
                DhikrBenefit(
                    title = "Comprehensive Ramadan dhikr",
                    description = "This dhikr combines testimony of faith, seeking forgiveness, asking for Paradise, and seeking refuge from the Fire — covering the essential supplications of Ramadan.",
                ),
                DhikrBenefit(
                    title = "Gates of Paradise",
                    description = "Asking for Paradise and seeking refuge from the Fire are among the most beloved supplications to Allah, especially during the blessed month.",
                ),
            ),
            suggestedGoals = listOf(
                SuggestedGoal(
                    label = "Daily 100x",
                    description = "Daily practice throughout Ramadan",
                    targetCount = 100,
                    frequencyType = FrequencyType.DAILY,
                ),
            ),
        ),

        "Allahummarhamni ya arhama rrahimin" to DhikrBenefitsData(
            benefits = listOf(
                DhikrBenefit(
                    title = "Seeking divine mercy",
                    description = "The first ten days of Ramadan are the days of mercy. This dhikr directly invokes Allah's mercy using His beautiful name Ar-Rahman.",
                ),
                DhikrBenefit(
                    title = "Most Merciful of the merciful",
                    description = "Calling upon Allah as the Most Merciful of those who show mercy is a powerful supplication that encompasses all forms of divine compassion.",
                ),
            ),
            suggestedGoals = listOf(
                SuggestedGoal(
                    label = "Daily 100x",
                    description = "Recite daily during the first 10 days of Ramadan",
                    targetCount = 100,
                    frequencyType = FrequencyType.DAILY,
                ),
            ),
        ),

        "Allahummaghfirli dhunubi ya rabbal aalameen" to DhikrBenefitsData(
            benefits = listOf(
                DhikrBenefit(
                    title = "Seeking forgiveness in Ramadan",
                    description = "The second ten days of Ramadan are the days of forgiveness. This dhikr asks Allah, the Lord of all worlds, to forgive one's sins.",
                ),
                DhikrBenefit(
                    title = "Lord of all worlds",
                    description = "Addressing Allah as Rabb al-Aalameen acknowledges His sovereignty over all creation while humbly seeking His forgiveness.",
                ),
            ),
            suggestedGoals = listOf(
                SuggestedGoal(
                    label = "Daily 100x",
                    description = "Recite daily during the second 10 days of Ramadan",
                    targetCount = 100,
                    frequencyType = FrequencyType.DAILY,
                ),
            ),
        ),
    )
}
