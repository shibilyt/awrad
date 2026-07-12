package app.awrad.awrad_dhikrgoalstracker.ui.screens.onboarding

import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.service.DownloadProgress

internal enum class AudioRowState { Pending, Downloading, Ready, Failed }

internal fun onboardingAudioStatus(
    dhikrsWithAudio: List<Dhikr>,
    downloadProgress: DownloadProgress,
    audioSetupStatus: AudioSetupStatus,
): AudioSetupStatus {
    val availableCount = dhikrsWithAudio.size
    val readyCount = onboardingAudioReadyCount(dhikrsWithAudio, downloadProgress)
    val failedCount = onboardingAudioFailedCount(dhikrsWithAudio, downloadProgress)

    return when {
        availableCount == 0 -> AudioSetupStatus.Empty
        downloadProgress.isDownloading -> AudioSetupStatus.Downloading
        readyCount == availableCount || audioSetupStatus == AudioSetupStatus.Complete -> AudioSetupStatus.Complete
        audioSetupStatus == AudioSetupStatus.PartialFailure ||
            (downloadProgress.isComplete && failedCount > 0) -> AudioSetupStatus.PartialFailure
        else -> AudioSetupStatus.Idle
    }
}

internal fun onboardingAudioReadyCount(
    dhikrsWithAudio: List<Dhikr>,
    downloadProgress: DownloadProgress,
): Int =
    dhikrsWithAudio.count { dhikr ->
        val fileName = dhikr.onboardingAudioFileName()
        dhikr.isDownloaded || (fileName != null && fileName in downloadProgress.completedFileNames)
    }

internal fun onboardingAudioFailedCount(
    dhikrsWithAudio: List<Dhikr>,
    downloadProgress: DownloadProgress,
): Int =
    dhikrsWithAudio.count { dhikr ->
        dhikr.onboardingAudioFileName()?.let { it in downloadProgress.failedFiles } == true
    }

internal fun onboardingAudioRowState(
    dhikr: Dhikr,
    downloadProgress: DownloadProgress,
    status: AudioSetupStatus,
): AudioRowState {
    val fileName = dhikr.onboardingAudioFileName()
    return when {
        dhikr.isDownloaded -> AudioRowState.Ready
        fileName != null && fileName in downloadProgress.completedFileNames -> AudioRowState.Ready
        fileName != null && fileName in downloadProgress.failedFiles -> AudioRowState.Failed
        status == AudioSetupStatus.Downloading &&
            fileName != null &&
            downloadProgress.currentFileName == fileName -> AudioRowState.Downloading
        else -> AudioRowState.Pending
    }
}

private fun Dhikr.onboardingAudioFileName(): String? =
    audioFileName ?: audioUrl?.substringAfterLast("/")?.takeIf { it.isNotBlank() }
