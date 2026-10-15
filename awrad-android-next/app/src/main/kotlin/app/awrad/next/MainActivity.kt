package app.awrad.next

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import app.awrad.core.designsystem.theme.AwradTheme
import app.awrad.next.navigation.AwradNavHost
import dagger.hilt.android.AndroidEntryPoint

/** Hosts the nav graph. Startup decisions live in [AppShellViewModel], not here. */
@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            AwradTheme {
                AwradNavHost()
            }
        }
    }
}
