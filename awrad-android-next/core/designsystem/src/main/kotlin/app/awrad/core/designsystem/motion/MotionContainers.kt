package app.awrad.core.designsystem.motion

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedContentScope
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.AnimatedVisibilityScope
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import app.awrad.core.designsystem.theme.AwradTheme

/**
 * `contentSwap`: shows [content] for [targetState], cross-fading when it changes (in over `color`, out over
 * `fade`), and springing to the new size. For text, status or a step of a form swapped in place.
 */
@Composable
public fun <S> AwradContentSwap(
    targetState: S,
    modifier: Modifier = Modifier,
    label: String = "contentSwap",
    contentKey: (targetState: S) -> Any? = { it },
    content: @Composable AnimatedContentScope.(targetState: S) -> Unit,
) {
    val motion = AwradTheme.motion
    AnimatedContent(
        targetState = targetState,
        modifier = modifier,
        transitionSpec = { motion.contentSwap() },
        label = label,
        contentKey = contentKey,
        content = content,
    )
}

/** `expand`: shows [content] while [visible], growing and fading in, shrinking and fading out. */
@Composable
public fun AwradExpand(
    visible: Boolean,
    modifier: Modifier = Modifier,
    label: String = "expand",
    content: @Composable AnimatedVisibilityScope.() -> Unit,
) {
    val motion = AwradTheme.motion
    AnimatedVisibility(
        visible = visible,
        modifier = modifier,
        enter = motion.expandEnter,
        exit = motion.expandExit,
        label = label,
        content = content,
    )
}
