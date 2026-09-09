package app.awrad.awrad_dhikrgoalstracker.data.sync

import org.junit.Assert.assertEquals
import org.junit.Test

class PracticeSettingsReconciliationTest {
    private val defaults = PracticePolicyValues(
        dayReset = "MIDNIGHT",
        calculationMethod = "KARACHI",
        madhab = "SHAFI",
    )

    @Test
    fun `anonymous non-default choices initialize a brand new default account`() {
        val local = defaults.copy(dayReset = "MAGHRIB")
        val remote = RemotePracticePolicyValues(
            dayReset = "midnight",
            calculationMethod = "karachi",
            madhab = "shafi",
            revision = 1,
        )

        assertEquals(
            PracticeSettingsSyncAction.UploadLocal,
            PracticeSettingsReconciliation.action(
                local = local,
                remote = remote,
                ownerUserId = null,
                currentUserId = "user-a",
                lastServerRevision = 0,
                localDirty = true,
                defaults = defaults,
            ),
        )
    }

    @Test
    fun `server policy wins when a different account uses this installation`() {
        assertEquals(
            PracticeSettingsSyncAction.ApplyRemote,
            PracticeSettingsReconciliation.action(
                local = defaults.copy(dayReset = "MAGHRIB"),
                remote = RemotePracticePolicyValues(
                    dayReset = "midnight",
                    calculationMethod = "karachi",
                    madhab = "shafi",
                    revision = 1,
                ),
                ownerUserId = "user-a",
                currentUserId = "user-b",
                lastServerRevision = 2,
                localDirty = true,
                defaults = defaults,
            ),
        )
    }

    @Test
    fun `dirty local policy uploads only against the revision it was read from`() {
        val remote = RemotePracticePolicyValues(
            dayReset = "midnight",
            calculationMethod = "karachi",
            madhab = "shafi",
            revision = 3,
        )

        assertEquals(
            PracticeSettingsSyncAction.UploadLocal,
            PracticeSettingsReconciliation.action(
                local = defaults.copy(dayReset = "MAGHRIB"),
                remote = remote,
                ownerUserId = "user-a",
                currentUserId = "user-a",
                lastServerRevision = 3,
                localDirty = true,
                defaults = defaults,
            ),
        )

        assertEquals(
            PracticeSettingsSyncAction.ApplyRemote,
            PracticeSettingsReconciliation.action(
                local = defaults.copy(dayReset = "MAGHRIB"),
                remote = remote.copy(revision = 4),
                ownerUserId = "user-a",
                currentUserId = "user-a",
                lastServerRevision = 3,
                localDirty = true,
                defaults = defaults,
            ),
        )
    }
}
