package app.awrad.awrad_dhikrgoalstracker.data.sync

import java.util.Locale

/** The native representation of the three account-wide practice choices. */
data class PracticePolicyValues(
    val dayReset: String,
    val calculationMethod: String,
    val madhab: String,
)

/** The server representation plus the revision it was read from. */
data class RemotePracticePolicyValues(
    val dayReset: String,
    val calculationMethod: String,
    val madhab: String,
    val revision: Int,
)

enum class PracticeSettingsSyncAction {
    ApplyRemote,
    UploadLocal,
}

/**
 * Decides which side is authoritative without doing I/O. Local values are
 * native-only until the account has been bound to a server revision.
 */
object PracticeSettingsReconciliation {
    fun action(
        local: PracticePolicyValues,
        remote: RemotePracticePolicyValues,
        ownerUserId: String?,
        currentUserId: String,
        lastServerRevision: Int,
        localDirty: Boolean,
        defaults: PracticePolicyValues,
    ): PracticeSettingsSyncAction {
        if (ownerUserId != null && ownerUserId != currentUserId) {
            return PracticeSettingsSyncAction.ApplyRemote
        }

        val anonymousLocalSeed = ownerUserId == null &&
            local != defaults &&
            remote.revision == 1 &&
            remote.toPolicyValues() == defaults

        if (anonymousLocalSeed) return PracticeSettingsSyncAction.UploadLocal

        val canUploadDirtyLocal = ownerUserId == currentUserId &&
            localDirty &&
            lastServerRevision == remote.revision

        return if (canUploadDirtyLocal) {
            PracticeSettingsSyncAction.UploadLocal
        } else {
            PracticeSettingsSyncAction.ApplyRemote
        }
    }

    private fun RemotePracticePolicyValues.toPolicyValues() = PracticePolicyValues(
        dayReset = dayReset.uppercase(Locale.US),
        calculationMethod = calculationMethod.uppercase(Locale.US),
        madhab = madhab.uppercase(Locale.US),
    )
}
