package app.awrad.next.debug

import android.app.Activity
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.lifecycle.lifecycleScope
import app.awrad.core.domain.AwradId
import app.awrad.core.domain.dhikr.DhikrKind
import app.awrad.core.domain.dhikr.Reference
import app.awrad.core.domain.personal.CustomDhikr
import app.awrad.core.domain.personal.CustomDhikrRepository
import app.awrad.core.domain.personal.CustomTransliteration
import app.awrad.core.domain.personal.OptionalTexts
import app.awrad.core.domain.personal.TagOutcome
import app.awrad.core.domain.personal.TagRepository
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * Debug builds only: fills the active profile with sample custom dhikrs, tags and tagged built-ins, through the
 * same repositories the screens use, for screenshots and manual checks (`adb shell am start -n
 * app.awrad.awrad_dhikrgoalstracker.next/app.awrad.next.debug.DebugSeedActivity`). It finishes when done.
 */
@AndroidEntryPoint
class DebugSeedActivity : ComponentActivity() {

    @Inject
    lateinit var dhikrs: CustomDhikrRepository

    @Inject
    lateinit var tags: TagRepository

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        lifecycleScope.launch {
            seed()
            setResult(Activity.RESULT_OK)
            finish()
        }
    }

    private suspend fun seed() {
        val morning = tag("Morning")
        val evening = tag("Evening")
        val protection = tag("Protection")
        SAMPLES.forEach { dhikrs.save(it) }
        tags.setTags(HASBIYALLAH.id, listOfNotNull(morning, evening, protection))
        tags.setTags(SUBHANALLAH.id, listOfNotNull(morning))
        tags.setTags(TAHLEEL, listOfNotNull(morning, evening))
        tags.setTags(IKHLAS, listOfNotNull(protection))
    }

    private suspend fun tag(name: String): AwradId? = (tags.create(name) as? TagOutcome.Saved)?.tag?.id

    private companion object {
        /** Built-in dhikrs to tag (catalog `tahleel` and `surah-ikhlas`). */
        val TAHLEEL = AwradId("6f04f77e-dcb6-4a29-9dc5-fcd3649c2961")
        val IKHLAS = AwradId("c88b9491-40ad-4b42-a5b8-e07c4b4d31ef")

        val HASBIYALLAH = CustomDhikr(
            id = AwradId("0192f0d0-0000-7000-8000-00000000d001"),
            kind = DhikrKind.DUA,
            arabic = "حَسْبِيَ ٱللَّهُ لَآ إِلَٰهَ إِلَّا هُوَ ۖ " +
                "عَلَيْهِ تَوَكَّلْتُ ۖ وَهُوَ رَبُّ ٱلْعَرْشِ ٱلْعَظِيمِ",
            title = OptionalTexts(en = "Hasbiyallah", ar = "حسبي الله", ml = "ഹസ്ബിയല്ലാഹ്"),
            transliteration = CustomTransliteration(
                en = "Hasbiyallahu la ilaha illa huwa, 'alayhi tawakkaltu wa huwa rabbul-'arshil-'azim",
            ),
            translation = OptionalTexts(
                en = "Allah is sufficient for me. There is no god but Him. In Him I put my trust, and He is the Lord " +
                    "of the Mighty Throne.",
                ml = "അല്ലാഹു എനിക്ക് മതി. അവനല്ലാതെ ആരാധ്യനില്ല.",
            ),
            references = listOf(
                Reference.Quran("quran", 9, 129, 129),
                Reference.Other("r1", "Taught by my teacher, to say seven times morning and evening"),
            ),
        )

        val SUBHANALLAH = CustomDhikr(
            id = AwradId("0192f0d0-0000-7000-8000-00000000d002"),
            kind = DhikrKind.DHIKR,
            arabic = "سُبْحَانَ ٱللَّهِ وَبِحَمْدِهِ",
            title = OptionalTexts(en = "Subhanallahi wa bihamdihi"),
            transliteration = CustomTransliteration(en = "Subhanallahi wa bihamdihi"),
            translation = OptionalTexts(en = "Glory be to Allah, and praise be to Him."),
        )

        val SAMPLES = listOf(SUBHANALLAH, HASBIYALLAH)
    }
}
