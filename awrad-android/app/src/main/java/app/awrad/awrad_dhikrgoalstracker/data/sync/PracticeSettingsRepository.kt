package app.awrad.awrad_dhikrgoalstracker.data.sync

import app.awrad.awrad_dhikrgoalstracker.data.network.AwradApiService
import app.awrad.awrad_dhikrgoalstracker.data.network.PracticeDeviceContextUpdateDto
import app.awrad.awrad_dhikrgoalstracker.data.network.PracticeDeviceContextUpdateRequest
import app.awrad.awrad_dhikrgoalstracker.data.network.PracticePolicyDto
import app.awrad.awrad_dhikrgoalstracker.data.network.PracticePolicyUpdateDto
import app.awrad.awrad_dhikrgoalstracker.data.network.PracticePolicyUpdateRequest
import app.awrad.awrad_dhikrgoalstracker.data.network.PracticeSettingsResponse
import app.awrad.awrad_dhikrgoalstracker.data.preferences.AuthTokenManager
import app.awrad.awrad_dhikrgoalstracker.data.preferences.UserPreferences
import java.io.IOException
import java.util.Locale
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.flow.first

/** Synchronizes account policy and installation-owned context independently of progress rows. */
@Singleton
class PracticeSettingsRepository @Inject constructor(
    private val api: AwradApiService,
    private val tokenManager: AuthTokenManager,
    private val userPreferences: UserPreferences,
) {
    private val defaults = PracticePolicyValues(
        dayReset = "MIDNIGHT",
        calculationMethod = "KARACHI",
        madhab = "SHAFI",
    )

    suspend fun synchronize() {
        val userId = tokenManager.userId.first() ?: return
        val installationId = tokenManager.installationId()
        val remote = fetch(installationId)
        val remotePolicy = remote.policy.toRemoteValues()
        val local = userPreferences.practicePolicy()
        val action = PracticeSettingsReconciliation.action(
            local = local,
            remote = remotePolicy,
            ownerUserId = userPreferences.practicePolicyOwnerUserId.first(),
            currentUserId = userId,
            lastServerRevision = userPreferences.practicePolicyServerRevision.first(),
            localDirty = userPreferences.practicePolicyDirty.first(),
            defaults = defaults,
        )

        val canonical = when (action) {
            PracticeSettingsSyncAction.ApplyRemote -> remote
            PracticeSettingsSyncAction.UploadLocal -> uploadLocal(
                installationId = installationId,
                expectedRevision = remotePolicy.revision,
                local = local,
            )
        }

        val canonicalPolicy = canonical.policy.toLocalValues()
            ?: throw IOException("Practice settings response contains an unsupported policy")
        userPreferences.applySyncedPracticePolicy(
            policy = canonicalPolicy,
            revision = canonical.policy.revision,
            ownerUserId = userId,
        )

        syncDeviceContext(installationId)
    }

    private suspend fun fetch(installationId: String): PracticeSettingsResponse {
        val response = api.practiceSettings(installationId)
        if (!response.isSuccessful) {
            throw IOException("Practice settings request failed: HTTP ${response.code()}")
        }
        return response.body() ?: throw IOException("Practice settings response was empty")
    }

    private suspend fun uploadLocal(
        installationId: String,
        expectedRevision: Int,
        local: PracticePolicyValues,
    ): PracticeSettingsResponse {
        val response = api.updatePracticePolicy(
            PracticePolicyUpdateRequest(
                installationId = installationId,
                expectedRevision = expectedRevision,
                policy = PracticePolicyUpdateDto(
                    dayReset = local.dayReset.lowercase(Locale.US),
                    calculationMethod = local.calculationMethod.lowercase(Locale.US),
                    madhab = local.madhab.lowercase(Locale.US),
                ),
            ),
        )

        if (response.isSuccessful) {
            return response.body() ?: throw IOException("Practice settings response was empty")
        }

        // A web or second mobile device may have changed the policy between
        // GET and PUT. Re-read and apply the server revision rather than
        // retrying a stale write or silently overwriting the account.
        if (response.code() == 409) return fetch(installationId)

        throw IOException("Practice settings update failed: HTTP ${response.code()}")
    }

    private suspend fun syncDeviceContext(installationId: String) {
        val context = api.updatePracticeDeviceContext(
            PracticeDeviceContextUpdateRequest(
                installationId = installationId,
                deviceContext = PracticeDeviceContextUpdateDto(
                    timezone = java.util.TimeZone.getDefault().id,
                    latitude = userPreferences.latitude.first(),
                    longitude = userPreferences.longitude.first(),
                    locationSource = "manual",
                ),
            ),
        )

        if (!context.isSuccessful) {
            throw IOException("Practice device context update failed: HTTP ${context.code()}")
        }
    }

    private fun PracticePolicyDto.toRemoteValues() = RemotePracticePolicyValues(
        dayReset = dayReset,
        calculationMethod = calculationMethod,
        madhab = madhab,
        revision = revision,
    )

    private fun PracticePolicyDto.toLocalValues(): PracticePolicyValues? {
        val policy = PracticePolicyValues(
            dayReset = dayReset.uppercase(Locale.US),
            calculationMethod = calculationMethod.uppercase(Locale.US),
            madhab = madhab.uppercase(Locale.US),
        )
        return policy.takeIf {
            it.dayReset in setOf("MIDNIGHT", "MAGHRIB") &&
                it.calculationMethod in CALCULATION_METHODS &&
                it.madhab in setOf("SHAFI", "HANAFI")
        }
    }

    private companion object {
        val CALCULATION_METHODS = setOf(
            "KARACHI", "NORTH_AMERICA", "MWL", "EGYPT", "UMM_AL_QURA",
            "MOON_SIGHTING", "DUBAI", "KUWAIT", "QATAR", "SINGAPORE",
        )
    }
}
