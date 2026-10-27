package app.awrad.next.gallery

import android.annotation.SuppressLint
import android.content.Context
import android.content.res.Configuration
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.LayoutDirection
import app.awrad.core.designsystem.motion.rememberSystemReducedMotion
import app.awrad.core.designsystem.theme.AwradTheme
import java.util.Locale

/**
 * The component gallery (debug builds only, its own launcher entry): every design-system component in every
 * state, with switches for the dark theme, right to left (Arabic) and reduced motion.
 *
 * For screenshots, intent extras set the starting state: `dark`, `rtl` and `reducedMotion` (booleans), `tab`
 * (0 to 3) and `sheet` (true opens the bottom sheet).
 */
class ComponentGalleryActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val start = GalleryStart(
            dark = intent.extras?.takeIf { it.containsKey(EXTRA_DARK) }?.getBoolean(EXTRA_DARK),
            rtl = intent.getBooleanExtra(EXTRA_RTL, false),
            reducedMotion = intent.extras?.takeIf { it.containsKey(EXTRA_REDUCED) }?.getBoolean(EXTRA_REDUCED),
            tab = intent.getIntExtra(EXTRA_TAB, 0),
            sheet = intent.getBooleanExtra(EXTRA_SHEET, false),
        )
        setContent {
            GalleryRoot(start = start, onDarkChange = ::applySystemBars)
        }
    }

    private fun applySystemBars(dark: Boolean) {
        val style = if (dark) {
            SystemBarStyle.dark(android.graphics.Color.TRANSPARENT)
        } else {
            SystemBarStyle.light(android.graphics.Color.TRANSPARENT, android.graphics.Color.TRANSPARENT)
        }
        enableEdgeToEdge(statusBarStyle = style, navigationBarStyle = style)
    }

    private companion object {
        const val EXTRA_DARK = "dark"
        const val EXTRA_RTL = "rtl"
        const val EXTRA_REDUCED = "reducedMotion"
        const val EXTRA_TAB = "tab"
        const val EXTRA_SHEET = "sheet"
    }
}

/** How the gallery starts; null follows the system. */
internal class GalleryStart(
    val dark: Boolean?,
    val rtl: Boolean,
    val reducedMotion: Boolean?,
    val tab: Int,
    val sheet: Boolean,
)

/** The gallery's own switches. */
internal class GallerySettings(
    val dark: Boolean,
    val rtl: Boolean,
    val reducedMotion: Boolean,
    val onDarkChange: (Boolean) -> Unit,
    val onRtlChange: (Boolean) -> Unit,
    val onReducedMotionChange: (Boolean) -> Unit,
)

@Composable
private fun GalleryRoot(start: GalleryStart, onDarkChange: (Boolean) -> Unit) {
    val systemDark = isSystemInDarkTheme()
    val systemReduced = rememberSystemReducedMotion()
    var dark by rememberSaveable { mutableStateOf(start.dark ?: systemDark) }
    var rtl by rememberSaveable { mutableStateOf(start.rtl) }
    var reduced by rememberSaveable { mutableStateOf(start.reducedMotion ?: systemReduced) }
    LaunchedEffect(dark, onDarkChange) { onDarkChange(dark) }
    val settings = GallerySettings(
        dark = dark,
        rtl = rtl,
        reducedMotion = reduced,
        onDarkChange = { dark = it },
        onRtlChange = { rtl = it },
        onReducedMotionChange = { reduced = it },
    )
    Localized(rtl = rtl) {
        AwradTheme(darkTheme = dark, reducedMotion = reduced) {
            GalleryScreen(settings = settings, startTab = start.tab, startWithSheet = start.sheet)
        }
    }
}

/** Arabic, right to left, or English, left to right, whatever the system language. */
// The gallery is debug-only and never ships in a bundle, so its locale switch can't miss a split.
@SuppressLint("AppBundleLocaleChanges")
@Composable
private fun Localized(rtl: Boolean, content: @Composable () -> Unit) {
    val base = LocalContext.current
    val locale = if (rtl) Locale.forLanguageTag("ar") else Locale.ENGLISH
    val system = LocalConfiguration.current
    val configuration = remember(system, rtl) {
        Configuration(system).apply {
            setLocale(locale)
            setLayoutDirection(locale)
        }
    }
    val context: Context = remember(base, configuration) { base.createConfigurationContext(configuration) }
    CompositionLocalProvider(
        LocalContext provides context,
        LocalConfiguration provides configuration,
        LocalLayoutDirection provides if (rtl) LayoutDirection.Rtl else LayoutDirection.Ltr,
        content = content,
    )
}
