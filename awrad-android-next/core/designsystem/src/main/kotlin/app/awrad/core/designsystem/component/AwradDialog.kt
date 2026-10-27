package app.awrad.core.designsystem.component

import android.os.Build
import android.view.Window
import android.view.WindowManager
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.paneTitle
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.compose.ui.window.DialogWindowProvider
import androidx.core.view.WindowCompat
import app.awrad.core.designsystem.theme.AwradContainer
import app.awrad.core.designsystem.theme.AwradTheme
import app.awrad.core.designsystem.theme.LocalAwradContainer

/**
 * A dialog (components.md, "Dialog"): `surfaceBar` fill, `dialog` (32) corners, `scrim` behind, `cardPadding`
 * inside, up to `dialogMaxWidth` wide. The [title] is `cardTitle`, the optional [text] `body`; the buttons
 * ([confirmButton], then [dismissButton] before it) sit at the end. Use an [AwradRowButton] to confirm (the
 * [AwradButtonVariant.Error] one for a destructive confirmation) and an [AwradTextButton] to dismiss. Tapping
 * the scrim or Back calls [onDismissRequest].
 */
// `modifier` styles the dialog, not the full-screen window it shows in (which has the scrim).
@Suppress("ModifierNotUsedAtRoot")
@Composable
public fun AwradDialog(
    onDismissRequest: () -> Unit,
    title: String,
    confirmButton: @Composable RowScope.() -> Unit,
    modifier: Modifier = Modifier,
    text: String? = null,
    dismissButton: (@Composable RowScope.() -> Unit)? = null,
) {
    OverlayWindow(onDismissRequest = onDismissRequest) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(AwradTheme.colors.scrim)
                .pointerInput(onDismissRequest) { detectTapGestures { onDismissRequest() } }
                .safeDrawingPadding()
                .padding(AwradTheme.spacing.pageMargin),
            contentAlignment = Alignment.Center,
        ) {
            DialogCard(
                title = title,
                text = text,
                confirmButton = confirmButton,
                dismissButton = dismissButton,
                modifier = modifier,
            )
        }
    }
}

@Composable
private fun DialogCard(
    title: String,
    text: String?,
    confirmButton: @Composable RowScope.() -> Unit,
    dismissButton: (@Composable RowScope.() -> Unit)?,
    modifier: Modifier = Modifier,
) {
    val colors = AwradTheme.colors
    Column(
        modifier = modifier
            .widthIn(max = AwradTheme.sizes.dialogMaxWidth)
            .fillMaxWidth()
            .clip(AwradTheme.shapes.dialog)
            .background(colors.surfaceBar)
            // Taps on the dialog don't reach the scrim behind it.
            .pointerInput(Unit) { detectTapGestures { } }
            .semantics { paneTitle = title }
            .padding(AwradTheme.spacing.cardPadding),
        verticalArrangement = Arrangement.spacedBy(AwradTheme.spacing.rowGap),
    ) {
        // A dialog counts as the page: secondary controls in it fill with `secondaryContainer`.
        CompositionLocalProvider(
            LocalContentColor provides colors.onSurface,
            LocalAwradContainer provides AwradContainer.Background,
        ) {
            Text(
                text = title,
                modifier = Modifier.semantics { heading() },
                style = AwradTheme.type.cardTitle,
                color = colors.onSurface,
            )
            if (text != null) {
                Text(text = text, style = AwradTheme.type.body, color = colors.onSurfaceVariant)
            }
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(AwradTheme.spacing.sm, Alignment.End),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                dismissButton?.invoke(this)
                confirmButton()
            }
        }
    }
}

/**
 * A full-screen window over the app for a dialog or bottom sheet, edge to edge, without the platform's dim: the
 * component draws the `scrim` itself. Back calls [onDismissRequest]. With [animatesItself], the window has no
 * platform animation (the bottom sheet runs its own `sheet` motion); otherwise it fades in and out.
 */
@Composable
internal fun OverlayWindow(
    onDismissRequest: () -> Unit,
    animatesItself: Boolean = false,
    content: @Composable () -> Unit,
) {
    Dialog(
        onDismissRequest = onDismissRequest,
        properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false),
    ) {
        val window = (LocalView.current.parent as? DialogWindowProvider)?.window
        SideEffect {
            window?.drawUnderSystemBars()
            window?.setDimAmount(0f)
            if (animatesItself) window?.setWindowAnimations(0)
        }
        content()
    }
}

/**
 * Lays the window out under the status and navigation bars with transparent bars, so the scrim covers the whole
 * screen; their icons are light, over the scrim.
 */
@Suppress("DEPRECATION") // The bar colours are deprecated from API 35, where they're transparent anyway.
private fun Window.drawUnderSystemBars() {
    setLayout(WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT)
    addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS)
    // A dialog window keeps clear of the system bars unless told otherwise.
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
        attributes = attributes.apply {
            fitInsetsTypes = 0
            layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
        }
    }
    WindowCompat.setDecorFitsSystemWindows(this, false)
    statusBarColor = android.graphics.Color.TRANSPARENT
    navigationBarColor = android.graphics.Color.TRANSPARENT
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) isNavigationBarContrastEnforced = false
    WindowCompat.getInsetsController(this, decorView).apply {
        isAppearanceLightStatusBars = false
        isAppearanceLightNavigationBars = false
    }
}
