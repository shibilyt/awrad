package app.awrad.awrad_dhikrgoalstracker.data.repository

import app.awrad.awrad_dhikrgoalstracker.service.CustomDhikrAudioStore
import app.awrad.awrad_dhikrgoalstracker.service.OwnedAudioFile

/**
 * Failure-safe owned-audio replace: keep previous file/reference until DAO commit succeeds;
 * on rollback delete only the newly promoted file.
 */
object OwnedAudioAttachRollbackPolicy {
    fun requireCustomDhikr(isCustom: Boolean) {
        require(isCustom) { "Owned audio may only attach to custom dhikrs" }
    }

    fun onDaoFailure(
        store: CustomDhikrAudioStore,
        previous: OwnedAudioFile?,
        promoted: OwnedAudioFile,
    ): OwnedAudioRollbackResult {
        store.deleteOwned(promoted.relativeFileName)
        return OwnedAudioRollbackResult(retainedRelativeFileName = previous?.relativeFileName)
    }

    fun onDaoSuccess(
        store: CustomDhikrAudioStore,
        previous: OwnedAudioFile?,
        promoted: OwnedAudioFile,
    ) {
        if (previous != null && previous.relativeFileName != promoted.relativeFileName) {
            store.deleteOwned(previous.relativeFileName)
        }
    }
}

data class OwnedAudioRollbackResult(
    val retainedRelativeFileName: String?,
)
