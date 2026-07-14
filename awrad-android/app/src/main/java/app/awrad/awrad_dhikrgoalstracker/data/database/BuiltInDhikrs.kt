package app.awrad.awrad_dhikrgoalstracker.data.database

import app.awrad.awrad_dhikrgoalstracker.data.database.entity.DhikrEntity
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory

object BuiltInDhikrs {

    val dhikrs = listOf(
        // QURAN
        DhikrEntity(
            id = BuiltInDhikrIds.SURAH_IKHLAS.id,
            catalogKey = BuiltInDhikrIds.SURAH_IKHLAS.catalogKey,
            title = "Surah Ikhlas",
            arabic = "بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ\nقُلۡ هُوَ ٱللَّهُ أَحَدٌ (1)\nٱللَّهُ ٱلصَّمَدُ (2)\nلَمۡ يَلِدۡ وَلَمۡ يُولَدۡ (3)\nوَلَمۡ يَكُن لَّهُۥ كُفُوًا أَحَدُۢ (4)",
            transliteration = "Qul huwa Allahu ahad",
            translation = "Surah Ikhlas",
            audioUrl = "https://dhikrs.awrad.app/ikhlas.mp3",
            audioFileName = "ikhlas.mp3",
            category = DhikrCategory.QURAN,
            audioCountPerPlay = 1,
            quranSurah = 112,
            quranAyahStart = 1,
            quranAyahEnd = 4,
        ),
        // PRAISE
        DhikrEntity(
            id = BuiltInDhikrIds.TAHLEEL.id,
            catalogKey = BuiltInDhikrIds.TAHLEEL.catalogKey,
            title = "Tahleel",
            arabic = "لَا إِلٰهَ إِلَّا ٱللَّٰهُ",
            transliteration = "La ilaha illallah",
            translation = "Tahleel",
            audioUrl = "https://dhikrs.awrad.app/1736077531573-g8kajuv6fww-tahleel.mp3",
            audioFileName = "tahleel.mp3",
            category = DhikrCategory.PRAISE,
            audioCountPerPlay = 2
        ),
        DhikrEntity(
            id = BuiltInDhikrIds.YA_WAHHABU.id,
            catalogKey = BuiltInDhikrIds.YA_WAHHABU.catalogKey,
            title = "Ya Wahhabu",
            arabic = "يَا وَهَّابُ",
            transliteration = "Ya Wahhabu",
            translation = "Ya Wahhabu",
            audioUrl = "https://dhikrs.awrad.app/ya-wahhabu-2.mp3",
            audioFileName = "ya-wahhabu.mp3",
            category = DhikrCategory.PRAISE,
            audioCountPerPlay = 2
        ),

        // FORGIVENESS
        DhikrEntity(
            id = BuiltInDhikrIds.ISTHIGHFAR.id,
            catalogKey = BuiltInDhikrIds.ISTHIGHFAR.catalogKey,
            title = "Isthighfar",
            arabic = "أَسْتَغْفِرُ ٱللَّٰهَ ٱلْعَظِيمَ",
            transliteration = "Asthaghfirullahil Azeem",
            translation = "Isthighfar",
            audioUrl = "https://dhikrs.awrad.app/1736083253280-c2kcxrk9cj-isthighfar.mp3",
            audioFileName = "isthighfar.mp3",
            category = DhikrCategory.FORGIVENESS
        ),

        // SWALATHS
        DhikrEntity(
            id = BuiltInDhikrIds.SWALATH_AL_FATHIMIYYA.id,
            catalogKey = BuiltInDhikrIds.SWALATH_AL_FATHIMIYYA.catalogKey,
            title = "Swalath Al Fathimiyya",
            arabic = "اللَّهُمَّ صَلِّ عَلَى النُّورِ وَأَهْلِهِ",
            transliteration = "Allahumma swalli ala nnoori wa ahlihi",
            translation = "Swalath Al Fathimiyya",
            audioUrl = "https://dhikrs.awrad.app/1736075795464-yh0twy42m-swalath-fatimiya.mp3",
            audioFileName = "swalath-fatimiya.mp3",
            category = DhikrCategory.SWALATHS
        ),
        DhikrEntity(
            id = BuiltInDhikrIds.SWALATH.id,
            catalogKey = BuiltInDhikrIds.SWALATH.catalogKey,
            title = "Swalath",
            arabic = "صَلَّى ٱللَّٰهُ عَلَىٰ مُحَمَّدٍ، صَلَّى ٱللَّٰهُ عَلَيْهِ وَسَلَّمَ",
            transliteration = "Swallallahu ala Muhammad, swallallahu alayhi wa sallim",
            translation = "Swalath",
            audioUrl = "https://dhikrs.awrad.app/1736510596621-oqiqm8yj15l-swalath-regular.mp3",
            audioFileName = "swalath-regular.mp3",
            category = DhikrCategory.SWALATHS
        ),
        DhikrEntity(
            id = BuiltInDhikrIds.SWALATH_SAYYIDINA.id,
            catalogKey = BuiltInDhikrIds.SWALATH_SAYYIDINA.catalogKey,
            title = "Swalath 2",
            arabic = "اللَّهُمَّ صَلِّ عَلَىٰ سَيِّدِنَا مُحَمَّدٍ وَعَلَىٰ آلِهِ وَصَحْبِهِ وَسَلِّمْ",
            transliteration = "Allahumma swalli ala sayyidina Muhammadin wa ala aalihi wa swahbihi wa sallim",
            translation = "Swalath 2",
            audioUrl = "https://dhikrs.awrad.app/1737527316685-7gkeld0j3oy-swalath-1.mp3",
            audioFileName = "swalath-1.mp3",
            category = DhikrCategory.SWALATHS
        ),
        DhikrEntity(
            id = BuiltInDhikrIds.SWALATH_AL_FATIH.id,
            catalogKey = BuiltInDhikrIds.SWALATH_AL_FATIH.catalogKey,
            title = "Swalath al Fatih",
            arabic = "اللَّهُمَّ صَلِّ عَلَىٰ سَيِّدِنَا مُحَمَّدٍ ❁ الْفَاتِحِ لِمَا أُغْلِقَ ❁ وَالْخَاتِمِ لِمَا سَبَقَ ❁ نَاصِرِ الْحَقِّ بِالْحَقِّ ❁ وَالْهَادِي إِلَىٰ صِرَاطِكَ الْمُسْتَقِيمِ ❁ وَعَلَىٰ آلِهِ حَقَّ قَدْرِهِ وَمِقْدَارِهِ الْعَظِيمِ",
            transliteration = "Swalath al Fatih",
            translation = "Swalath al Fatih",
            audioUrl = "https://dhikrs.awrad.app/swalath_fatih.mp3",
            audioFileName = "swalath-fatih.mp3",
            category = DhikrCategory.SWALATHS
        ),
        DhikrEntity(
            id = BuiltInDhikrIds.SWALATH_AL_NARIYYA.id,
            catalogKey = BuiltInDhikrIds.SWALATH_AL_NARIYYA.catalogKey,
            title = "Swalath al Nariyya",
            arabic = "اللَّهُمَّ صَلِّ صَلَاةً كَامِلَةً وَسَلِّمْ سَلَامًا تَامًّا عَلَىٰ سَيِّدِنَا مُحَمَّدٍ الَّذِي تَنْحَلُّ بِهِ الْعُقَدُ وَتَنْفَرِجُ بِهِ الْكُرَبُ وَتُقْضَىٰ بِهِ الْحَوَائِجُ وَتُنَالُ بِهِ الرَّغَائِبُ وَحُسْنُ الْخَوَاتِمِ وَيُسْتَسْقَى الْغَمَامُ بِوَجْهِهِ الْكَرِيمِ وَعَلَىٰ آلِهِ وَصَحْبِهِ فِي كُلِّ لَمْحَةٍ وَنَفَسٍ بِعَدَدِ كُلِّ مَعْلُومٍ لَكَ",
            transliteration = "Swalath al Nariyya",
            translation = "Swalath al Nariyya",
            audioUrl = "https://dhikrs.awrad.app/swalath_nariyya.mp3",
            audioFileName = "swalath-nariyya.mp3",
            category = DhikrCategory.SWALATHS
        ),
        DhikrEntity(
            id = BuiltInDhikrIds.SWALATH_FOR_DEBT.id,
            catalogKey = BuiltInDhikrIds.SWALATH_FOR_DEBT.catalogKey,
            title = "Swalath for Debt",
            arabic = "اللَّهُمَّ صَلِّ عَلَىٰ مُحَمَّدٍ عَبْدِكَ وَرَسُولِكَ وَعَلَى الْمُؤْمِنِينَ وَالْمُسْلِمِينَ وَلِلْمُؤْمِنَاتِ وَالْمُسْلِمَاتِ",
            transliteration = "Allāhumma ṣalli ʿalā Muḥammadin ʿabdika wa rasūlika wa ʿalā al-muʾminīna wa al-muslimīna wa lil-muʾmināti wa al-muslimāt.",
            translation = "O Allah, send blessings upon Muhammad, Your servant and Your messenger, and upon the believing men and the Muslim men, and upon the believing women and the Muslim women.",
            audioUrl = "https://dhikrs.awrad.app/swalath_tajul_ulama.mp3",
            audioFileName = "swalath_tajul_ulama.mp3",
            category = DhikrCategory.SWALATHS
        ),

        // RAMADAN
        DhikrEntity(
            id = BuiltInDhikrIds.RAMADAN_DHIKR.id,
            catalogKey = BuiltInDhikrIds.RAMADAN_DHIKR.catalogKey,
            title = "Ramadan Dhikr",
            arabic = "أَشْهَدُ أَنْ لَا إِلٰهَ إِلَّا ٱللَّٰهُ، أَسْتَغْفِرُ ٱللَّٰهَ، أَسْأَلُكَ ٱلْجَنَّةَ وَأَعُوذُ بِكَ مِنَ ٱلنَّارِ",
            transliteration = "Ash'hadu an la ilaha illallahu, asthaghfirullah, as'alukal jannatha wa au'dhu bika mina nnaar",
            translation = "Dhikr for whole Ramadan",
            audioUrl = "https://dhikrs.awrad.app/ramadan_full.mp3",
            audioFileName = "ramadan-full.mp3",
            category = DhikrCategory.RAMADAN
        ),
        DhikrEntity(
            id = BuiltInDhikrIds.RAMADAN_FIRST_TEN_NIGHTS.id,
            catalogKey = BuiltInDhikrIds.RAMADAN_FIRST_TEN_NIGHTS.catalogKey,
            title = "First 10 Nights",
            arabic = "اللَّهُمَّ ٱرْحَمْنِي يَا أَرْحَمَ ٱلرَّاحِمِينَ",
            transliteration = "Allahummarhamni ya arhama rrahimin",
            translation = "Ramadan first 10 dhikr",
            audioUrl = "https://dhikrs.awrad.app/ramadan_first10.mp3",
            audioFileName = "ramadan-first10.mp3",
            category = DhikrCategory.RAMADAN
        ),
        DhikrEntity(
            id = BuiltInDhikrIds.RAMADAN_SECOND_TEN_NIGHTS.id,
            catalogKey = BuiltInDhikrIds.RAMADAN_SECOND_TEN_NIGHTS.catalogKey,
            title = "Second 10 Nights",
            arabic = "اللَّهُمَّ ٱغْفِرْ لِي ذُنُوبِي يَا رَبَّ ٱلْعَالَمِينَ",
            transliteration = "Allahummaghfirli dhunubi ya rabbal aalameen",
            translation = "Ramadan second 10 dhikr",
            audioUrl = "https://dhikrs.awrad.app/ramadan_second10.mp3",
            audioFileName = "ramadan-second10.mp3",
            category = DhikrCategory.RAMADAN
        ),
    ) + AsmaUlHusnaSeed.dhikrs
}
