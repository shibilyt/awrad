package app.awrad.awrad_dhikrgoalstracker.notification

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.delay
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class NotificationObligationRequestDispatcherTest {

    @Test
    fun requestBeforeStartIsRetainedAndRepeatedStartUsesOneCollector() = runTest {
        val dispatcher = dispatcher(this)
        val calls = mutableListOf<Set<NotificationObligationRequest>>()

        dispatcher.request(NotificationObligationRequestReason.GOAL_MUTATION)
        dispatcher.start { calls += it }
        dispatcher.start { calls += it }
        advanceUntilIdle()

        assertEquals(
            listOf(setOf(NotificationObligationRequest(NotificationObligationRequestReason.GOAL_MUTATION))),
            calls,
        )
    }

    @Test
    fun requestDuringReconciliationCausesOneFollowUpPass() = runTest {
        val dispatcher = dispatcher(this)
        val calls = mutableListOf<Set<NotificationObligationRequest>>()

        dispatcher.start { reasons ->
            calls += reasons
            if (calls.size == 1) {
                dispatcher.request(NotificationObligationRequestReason.COUNT_MUTATION)
            }
        }
        dispatcher.request(NotificationObligationRequestReason.STARTUP)
        advanceUntilIdle()

        assertEquals(
            listOf(
                setOf(NotificationObligationRequest(NotificationObligationRequestReason.STARTUP)),
                setOf(NotificationObligationRequest(NotificationObligationRequestReason.COUNT_MUTATION)),
            ),
            calls,
        )
    }

    private fun dispatcher(scope: TestScope): NotificationObligationRequestDispatcher =
        NotificationObligationRequestDispatcher(
            scope = CoroutineScope(StandardTestDispatcher(scope.testScheduler)),
        )
}
