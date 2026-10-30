package app.awrad.core.domain

import app.awrad.core.testing.fixtures.FixtureModel
import app.awrad.core.testing.fixtures.FixtureRunner
import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * Guard: every shared rule file has a runner here, so a new fixture file can't go unrun on Android.
 * Adding a file to `contracts/<model>/v1/fixtures/` fails this test until a `…FixtureTest` runs it.
 */
class FixtureCoverageTest {

    @Test
    fun `every goal-model rule file has a runner`() {
        assertEquals(
            setOf(
                "effective_practice_day", // practice.EffectivePracticeDayFixtureTest
                "goal_is_due", // goal.rules.GoalIsDueFixtureTest
                "requirement_standing", // goal.rules.RequirementStandingFixtureTest
                "days_per_period", // goal.rules.DaysPerPeriodFixtureTest
                "goal_completion", // goal.rules.GoalCompletionFixtureTest
                "goal_streak", // goal.rules.GoalStreakFixtureTest
                "goal_validity", // goal.GoalValidityFixtureTest
            ),
            FixtureRunner.rules(FixtureModel.GOAL_MODEL),
        )
    }

    @Test
    fun `every hijri-calendar rule file has a runner`() {
        assertEquals(
            setOf(
                "hijri_date", // hijri.HijriDateFixtureTest
                "hijri_corrections_validity", // hijri.HijriCorrectionsValidityFixtureTest
            ),
            FixtureRunner.rules(FixtureModel.HIJRI_CALENDAR),
        )
    }

    @Test
    fun `every account-model rule file has a runner`() {
        assertEquals(
            setOf(
                "email_input", // account.EmailInputFixtureTest
                "password_policy", // account.PasswordPolicyFixtureTest
                "email_code_input", // account.EmailCodeInputFixtureTest
            ),
            FixtureRunner.rules(FixtureModel.ACCOUNT_MODEL),
        )
    }

    @Test
    fun `every dhikr-catalog rule file has a runner`() {
        assertEquals(
            setOf(
                "dhikr_search_normalization", // dhikr.DhikrSearchNormalizationFixtureTest
                "dhikr_search", // dhikr.DhikrSearchFixtureTest
            ),
            FixtureRunner.rules(FixtureModel.DHIKR_CATALOG),
        )
    }

    @Test
    fun `every sync rule file the phones run has a runner`() {
        assertEquals(
            setOf(
                "tag_name_normalization", // personal.TagNameNormalizationFixtureTest
                "custom_dhikr_validity", // personal.CustomDhikrValidityFixtureTest
                "outbox_enqueue", // sync.OutboxEnqueueFixtureTest
                "apply_changes", // sync.ApplyChangesFixtureTest
                "profile_switch", // sync.ProfileSwitchFixtureTest
            ),
            FixtureRunner.rules(FixtureModel.SYNC) - SERVER_ONLY_SYNC_RULES,
        )
    }

    @Test
    fun `every audio rule file has a runner`() {
        assertEquals(
            setOf(
                "audio_upload_validity", // audio.AudioUploadValidityFixtureTest
            ),
            FixtureRunner.rules(FixtureModel.AUDIO),
        )
    }

    @Test
    fun `every identity rule file has a runner`() {
        assertEquals(
            setOf(
                "uuid_format", // UuidFormatFixtureTest
                "uuid_v7_layout", // UuidV7LayoutFixtureTest
            ),
            FixtureRunner.rules(FixtureModel.IDENTITY),
        )
    }

    @Test
    fun `every practice-settings rule file has a runner`() {
        assertEquals(
            setOf(
                "practice_policy_validity", // practice.PracticePolicyValidityFixtureTest
                "practice_policy_merge", // practice.PracticePolicyMergeFixtureTest
                "practice_policy_first_sign_in", // practice.PracticePolicyFirstSignInFixtureTest
                "maghrib_time", // practice.MaghribTimeFixtureTest
            ),
            FixtureRunner.rules(FixtureModel.PRACTICE_SETTINGS),
        )
    }

    @Test
    fun `every places rule file has a runner`() {
        assertEquals(
            setOf(
                "city_search", // places.CitySearchFixtureTest
            ),
            FixtureRunner.rules(FixtureModel.PLACES),
        )
    }

    private companion object {
        /** The server's protocol spec (contracts/sync/v1/README.md, "Fixtures"): phones don't run these. */
        val SERVER_ONLY_SYNC_RULES = setOf("sync_receipts", "sync_changes_feed")
    }
}
