package app.awrad.next

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import app.awrad.core.data.sync.SyncLifecycle
import app.awrad.core.designsystem.theme.AwradTheme
import app.awrad.next.navigation.AwradNavHost
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.launch
import javax.inject.Inject

/** Hosts the nav graph. Startup decisions live in [AppShellViewModel], not here. */
@AndroidEntryPoint
class MainActivity : ComponentActivity() {

    @Inject
    lateinit var sync: SyncLifecycle

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        // Sync runs while the app is open: at start, after edits and every 5 minutes. Signed out it sends nothing.
        lifecycleScope.launch { repeatOnLifecycle(Lifecycle.State.STARTED) { sync.syncWhileOpen() } }
        setContent {
            AwradTheme {
                AwradNavHost()
            }
        }
    }
}
