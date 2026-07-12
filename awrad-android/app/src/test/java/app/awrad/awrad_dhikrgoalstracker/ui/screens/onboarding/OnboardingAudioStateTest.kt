package app.awrad.awrad_dhikrgoalstracker.ui.screens.onboarding

import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory
import app.awrad.awrad_dhikrgoalstracker.service.DownloadProgress
import org.junit.Assert.assertEquals
import org.junit.Test

class OnboardingAudioStateTest {

    @Test
    fun `completed file names mark prior downloads ready while next file downloads`() {
        val first = dhikr(id = 1, fileName = "first.mp3")
        val second = dhikr(id = 2, fileName = "second.mp3")
        val third = dhikr(id = 3, fileName = "third.mp3")
        val progress = DownloadProgress(
            totalFiles = 3,
            completedFiles = 1,
            completedFileNames = setOf("first.mp3"),
            currentFileName = "second.mp3",
            isDownloading = true,
        )

        val status = onboardingAudioStatus(
            dhikrsWithAudio = listOf(first, second, third),
            downloadProgress = progress,
            audioSetupStatus = AudioSetupStatus.Idle,
        )

        assertEquals(AudioSetupStatus.Downloading, status)
        assertEquals(1, onboardingAudioReadyCount(listOf(first, second, third), progress))
        assertEquals(AudioRowState.Ready, onboardingAudioRowState(first, progress, status))
        assertEquals(AudioRowState.Downloading, onboardingAudioRowState(second, progress, status))
        assertEquals(AudioRowState.Pending, onboardingAudioRowState(third, progress, status))
    }

    @Test
    fun `completed file names can complete audio scene before room emits downloaded rows`() {
        val dhikrs = listOf(
            dhikr(id = 1, fileName = "first.mp3"),
            dhikr(id = 2, fileName = "second.mp3"),
        )
        val progress = DownloadProgress(
            totalFiles = 2,
            completedFiles = 2,
            completedFileNames = setOf("first.mp3", "second.mp3"),
            isComplete = true,
        )

        val status = onboardingAudioStatus(
            dhikrsWithAudio = dhikrs,
            downloadProgress = progress,
            audioSetupStatus = AudioSetupStatus.Downloading,
        )

        assertEquals(AudioSetupStatus.Complete, status)
        assertEquals(2, onboardingAudioReadyCount(dhikrs, progress))
    }

    @Test
    fun `failed file names stay failed instead of being counted ready`() {
        val first = dhikr(id = 1, fileName = "first.mp3")
        val second = dhikr(id = 2, fileName = "second.mp3")
        val progress = DownloadProgress(
            totalFiles = 2,
            completedFiles = 2,
            completedFileNames = setOf("first.mp3"),
            isComplete = true,
            failedFiles = listOf("second.mp3"),
        )

        val status = onboardingAudioStatus(
            dhikrsWithAudio = listOf(first, second),
            downloadProgress = progress,
            audioSetupStatus = AudioSetupStatus.Downloading,
        )

        assertEquals(AudioSetupStatus.PartialFailure, status)
        assertEquals(1, onboardingAudioReadyCount(listOf(first, second), progress))
        assertEquals(1, onboardingAudioFailedCount(listOf(first, second), progress))
        assertEquals(AudioRowState.Ready, onboardingAudioRowState(first, progress, status))
        assertEquals(AudioRowState.Failed, onboardingAudioRowState(second, progress, status))
    }

    private fun dhikr(id: Long, fileName: String): Dhikr =
        Dhikr(
            id = id,
            title = fileName,
            arabic = "",
            transliteration = fileName,
            translation = "",
            audioUrl = "https://dhikrs.awrad.app/$fileName",
            audioFileName = fileName,
            category = DhikrCategory.GENERAL,
        )
}
