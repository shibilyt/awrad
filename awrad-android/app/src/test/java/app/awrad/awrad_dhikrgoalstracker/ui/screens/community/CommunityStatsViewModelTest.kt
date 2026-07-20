package app.awrad.awrad_dhikrgoalstracker.ui.screens.community

import app.awrad.awrad_dhikrgoalstracker.data.repository.CommunityStats
import app.awrad.awrad_dhikrgoalstracker.data.repository.CommunityStatsRepository
import java.io.IOException
import java.math.BigDecimal
import java.math.BigInteger
import java.time.Instant
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class CommunityStatsViewModelTest {
    private val dispatcher = StandardTestDispatcher()

    @Before
    fun setUp() = Dispatchers.setMain(dispatcher)

    @After
    fun tearDown() = Dispatchers.resetMain()

    @Test
    fun `initial load publishes success`() = runTest(dispatcher) {
        val repository = FakeCommunityStatsRepository(mutableListOf(Result.success(stats())))
        val viewModel = CommunityStatsViewModel(repository)

        assertTrue(viewModel.uiState.value.isLoading)
        advanceUntilIdle()

        assertFalse(viewModel.uiState.value.isLoading)
        assertEquals(BigInteger("34567"), viewModel.uiState.value.stats?.approximateTotalCounts)
        assertFalse(viewModel.uiState.value.hasError)
    }

    @Test
    fun `failure is recoverable and retry loads stats`() = runTest(dispatcher) {
        val repository = FakeCommunityStatsRepository(
            mutableListOf(Result.failure(IOException("offline")), Result.success(stats())),
        )
        val viewModel = CommunityStatsViewModel(repository)
        advanceUntilIdle()

        assertTrue(viewModel.uiState.value.hasError)
        assertNull(viewModel.uiState.value.stats)

        viewModel.retry()
        assertTrue(viewModel.uiState.value.isLoading || viewModel.uiState.value.hasError)
        advanceUntilIdle()

        assertEquals(2, repository.calls)
        assertFalse(viewModel.uiState.value.hasError)
        assertEquals(stats(), viewModel.uiState.value.stats)
        assertEquals(listOf(false, true), repository.forceRefreshCalls)
    }

    @Test
    fun `manual refresh bypasses cached response`() = runTest(dispatcher) {
        val repository = FakeCommunityStatsRepository(
            mutableListOf(Result.success(stats()), Result.success(stats().copy(totalTrackedGoals = 13))),
        )
        val viewModel = CommunityStatsViewModel(repository)
        advanceUntilIdle()

        viewModel.refresh()
        advanceUntilIdle()

        assertEquals(13L, viewModel.uiState.value.stats?.totalTrackedGoals)
        assertEquals(listOf(false, true), repository.forceRefreshCalls)
    }

    private fun stats() = CommunityStats(
        asOf = Instant.parse("2026-07-19T16:00:00Z"),
        countSemantics = "current_canonical_net",
        totalTrackedGoals = 12,
        approximateTotalCounts = BigInteger("34567"),
        approximateDhikrHours = BigDecimal("9.6"),
        secondsPerCount = 1,
        dailyCounts = emptyList(),
    )
}

private class FakeCommunityStatsRepository(
    private val results: MutableList<Result<CommunityStats>>,
) : CommunityStatsRepository {
    var calls = 0
        private set
    val forceRefreshCalls = mutableListOf<Boolean>()

    override suspend fun getStats(forceRefresh: Boolean): CommunityStats {
        calls += 1
        forceRefreshCalls += forceRefresh
        return results.removeAt(0).getOrThrow()
    }
}
