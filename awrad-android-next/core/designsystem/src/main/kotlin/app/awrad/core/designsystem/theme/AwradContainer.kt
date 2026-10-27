package app.awrad.core.designsystem.theme

import androidx.compose.runtime.ProvidableCompositionLocal
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color

/**
 * The colour content sits on. The design has no outlines, so a field or a secondary button shows itself by
 * filling with the other colour: `surface` on a `background`, `background` on a `surface` card.
 */
public enum class AwradContainer { Background, Surface }

/**
 * The container the current content sits on: [AwradContainer.Background] unless something says otherwise.
 * `AwradCard` sets [AwradContainer.Surface]; provide it yourself around any other `surface` fill.
 */
public val LocalAwradContainer: ProvidableCompositionLocal<AwradContainer> =
    staticCompositionLocalOf { AwradContainer.Background }

/** The fill for a field or a secondary button on [container]. */
public fun AwradColors.fillOn(container: AwradContainer): Color = when (container) {
    AwradContainer.Background -> surface
    AwradContainer.Surface -> background
}
