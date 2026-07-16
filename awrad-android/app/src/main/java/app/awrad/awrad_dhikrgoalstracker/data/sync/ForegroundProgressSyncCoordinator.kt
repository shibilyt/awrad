package app.awrad.awrad_dhikrgoalstracker.data.sync

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.SystemClock
import android.util.Log
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.SyncDao
import dagger.hilt.android.qualifiers.ApplicationContext
import java.util.concurrent.atomic.AtomicBoolean
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.math.pow
import kotlin.random.Random
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.merge
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withTimeoutOrNull

internal object ForegroundProgressSyncPolicy {
    const val MUTATION_DEBOUNCE_MS = 2_000L
    const val COUNTER_INTERVAL_MS = 10_000L
    const val FOREGROUND_INTERVAL_MS = 60_000L
    const val INITIAL_BACKOFF_MS = 5_000L
    const val MAX_BACKOFF_MS = 5 * 60_000L
    const val BACKGROUND_FLUSH_TIMEOUT_MS = 5_000L

    fun intervalMillis(countingActive: Boolean, randomUnit: Double): Long {
        val base = if (countingActive) COUNTER_INTERVAL_MS else FOREGROUND_INTERVAL_MS
        val jitter = 0.8 + (randomUnit.coerceIn(0.0, 1.0) * 0.4)
        return (base * jitter).toLong().coerceAtLeast(1L)
    }

    fun backoffMillis(consecutiveFailures: Int): Long {
        if (consecutiveFailures <= 0) return 0
        val multiplier = 2.0.pow((consecutiveFailures - 1).coerceAtMost(16)).toLong()
        return (INITIAL_BACKOFF_MS * multiplier).coerceAtMost(MAX_BACKOFF_MS)
    }
}

@Singleton
class ProgressSyncActivityTracker @Inject constructor() {
    internal val countingActive = MutableStateFlow(false)

    fun setCountingActive(active: Boolean) {
        countingActive.value = active
    }
}

@OptIn(ExperimentalCoroutinesApi::class, FlowPreview::class)
@Singleton
class ForegroundProgressSyncCoordinator @Inject constructor(
    @ApplicationContext context: Context,
    private val engine: ProgressSyncEngine,
    private val syncDao: SyncDao,
    private val activityTracker: ProgressSyncActivityTracker,
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val foreground = MutableStateFlow(false)
    private val networkAvailable = MutableStateFlow(false)
    private val started = AtomicBoolean(false)
    private val runMutex = Mutex()
    private val connectivityManager =
        context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    private var consecutiveFailures = 0
    private var retryNotBefore = 0L

    private val networkCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            consecutiveFailures = 0
            retryNotBefore = 0L
            networkAvailable.value = true
        }

        override fun onLost(network: Network) {
            networkAvailable.value = hasUsableNetwork()
        }

        override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) {
            networkAvailable.value = capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        }
    }

    fun start() {
        if (!started.compareAndSet(false, true)) return
        networkAvailable.value = hasUsableNetwork()
        connectivityManager.registerDefaultNetworkCallback(networkCallback)

        scope.launch {
            combine(
                foreground,
                activityTracker.countingActive,
                networkAvailable,
            ) { isForeground, isCounting, isOnline ->
                ActiveState(isForeground, isCounting, isOnline)
            }
                .distinctUntilChanged()
                .flatMapLatest { state ->
                    flow {
                        if (!state.foreground || !state.online) return@flow
                        emit(Unit)
                        while (true) {
                            delay(
                                ForegroundProgressSyncPolicy.intervalMillis(
                                    countingActive = state.counting,
                                    randomUnit = Random.nextDouble(),
                                ),
                            )
                            emit(Unit)
                        }
                    }
                }
                .collect { synchronizeIfAllowed() }
        }

        scope.launch {
            merge(
                syncDao.observeSyncRequested().filter { it }.map { Unit },
                syncDao.observeLatestOpenBatchUpdate().filterNotNull().map { Unit },
            )
                .debounce(ForegroundProgressSyncPolicy.MUTATION_DEBOUNCE_MS)
                .collect {
                    if (foreground.value && networkAvailable.value) synchronizeIfAllowed()
                }
        }
    }

    fun setAppForeground(active: Boolean) {
        val wasForeground = foreground.value
        foreground.value = active
        if (wasForeground && !active && networkAvailable.value) {
            scope.launch {
                withTimeoutOrNull(ForegroundProgressSyncPolicy.BACKGROUND_FLUSH_TIMEOUT_MS) {
                    synchronizeIfAllowed(ignoreBackoff = true)
                }
            }
        }
    }

    private suspend fun synchronizeIfAllowed(ignoreBackoff: Boolean = false) {
        runMutex.withLock {
            val now = SystemClock.elapsedRealtime()
            if (!ignoreBackoff && now < retryNotBefore) return
            try {
                engine.synchronize()
                consecutiveFailures = 0
                retryNotBefore = 0L
            } catch (error: Exception) {
                consecutiveFailures += 1
                retryNotBefore = now +
                    ForegroundProgressSyncPolicy.backoffMillis(consecutiveFailures)
                Log.w(TAG, "Foreground progress synchronization failed", error)
                runCatching { engine.recordFailure(error) }
            }
        }
    }

    private fun hasUsableNetwork(): Boolean =
        connectivityManager.getNetworkCapabilities(connectivityManager.activeNetwork)
            ?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true

    private data class ActiveState(
        val foreground: Boolean,
        val counting: Boolean,
        val online: Boolean,
    )

    private companion object {
        const val TAG = "ForegroundProgressSync"
    }
}
