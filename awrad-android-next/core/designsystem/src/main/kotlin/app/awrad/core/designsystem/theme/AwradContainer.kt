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

/** The fill for a field on [container]. */
public fun AwradColors.fillOn(container: AwradContainer): Color = when (container) {
    AwradContainer.Background -> surface
    AwradContainer.Surface -> background
}

/**
 * The fill for a secondary control (a secondary button, an unselected option row or segmented pill) on
 * [container]: `secondaryContainer` on the page, but `background` on a `surface` area, since in light
 * `secondaryContainer` is the same colour as `surface` and the control would vanish there. Dialogs and sheets
 * count as the page.
 */
public fun AwradColors.secondaryFillOn(container: AwradContainer): Color = when (container) {
    AwradContainer.Background -> secondaryContainer
    AwradContainer.Surface -> background
}

/** Text and icons on [secondaryFillOn]: `onSecondaryContainer` on the page, `onSurface` on a `surface` area. */
public fun AwradColors.onSecondaryFillOn(container: AwradContainer): Color = when (container) {
    AwradContainer.Background -> onSecondaryContainer
    AwradContainer.Surface -> onSurface
}
