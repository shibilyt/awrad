package app.awrad.next

import android.app.Application
import app.awrad.core.data.sync.SyncLifecycle
import app.awrad.core.network.session.DeviceSessionManager
import dagger.hilt.android.HiltAndroidApp
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltAndroidApp
class AwradApplication : Application() {

    @Inject
    lateinit var deviceSessions: DeviceSessionManager

    @Inject
    lateinit var sync: SyncLifecycle

    private val scope = MainScope()

    override fun onCreate() {
        super.onCreate()
        // A sign-out that couldn't reach the server earlier is sent again on each start.
        scope.launch { deviceSessions.retryPendingSignOuts() }
        // Signing in and out moves between local profiles for as long as the app runs (contracts/sync/v1).
        scope.launch { sync.followAccount() }
    }
}
